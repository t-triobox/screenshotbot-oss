;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defpackage :util/store
  (:use #:cl
        #:bknr.datastore
        #:util/file-lock)
  (:local-nicknames (#:a #:alexandria))
  (:export
   #:prepare-store-for-test
   #:prepare-store
   #:verify-store
   #:add-datastore-hook
   #:object-store
   #:safe-mp-store
   #:with-test-store
   #:*object-store*
   #:store-subsystems
   #:validate-indices))
(in-package :util/store)

(defvar *object-store*)

(defvar *datastore-hooks* nil)
(defvar *calledp* nil)

(defun add-datastore-hook (fn)
  (unless *calledp*
   (pushnew fn *datastore-hooks*)))

(defun dispatch-datastore-hooks ()
  (mapc 'funcall *datastore-hooks*)
  (setf *calledp* t))

(defun object-store ()
  (let* ((dir *object-store*)
         (dir (if (str:ends-with-p "/" dir) dir (format nil "~a/" dir))))
   (let ((path (pathname dir)))
     (ensure-directories-exist path)
     path)))

(defclass safe-mp-store (bknr.datastore:mp-store)
  (lock))

(defmethod initialize-instance :before ((store safe-mp-store) &key directory &allow-other-keys)
  (with-slots (lock) store
    (setf lock
          (make-instance 'file-lock
                         :file (path:catfile directory
                                             "store.lock")))))

(defmethod bknr.datastore::close-store-object :after ((store safe-mp-store))
  (with-slots (lock) store
    (release-file-lock lock)))

(defun store-subsystems ()
  (list (make-instance 'bknr.datastore:store-object-subsystem)
        (make-instance 'bknr.datastore:blob-subsystem)))

(defun prepare-store-for-test (&key (dir "~/test-store/"))
  (make-instance 'safe-mp-store
                 :directory dir
                 :subsystems (store-subsystems)))

(defmacro with-test-store (() &body body)
  `(call-with-test-store (lambda () ,@body)))

(defun call-with-test-store (fn)
  #-buck
  (funcall fn)
  #+buck
  (when (boundp 'bknr.datastore:*store*)
    (error "Don't run this test in a live program with an existing store"))
  #+buck
  (let ((*store* nil))
    (tmpdir:with-tmpdir (dir)
      (prepare-store-for-test :dir dir)
      (assert bknr.datastore:*store*)
      (funcall fn))))

(defun prepare-store ()
  (setf bknr.datastore:*store-debug* t)
  (make-instance 'safe-mp-store
                 :directory (object-store)
                 :subsystems (store-subsystems))
  (dispatch-datastore-hooks))

(defun verify-store ()
  (let ((store-dir (object-store)))
    (tmpdir:with-tmpdir (dir)
      (let ((out-current (path:catdir dir "current/")))
        (log:info "Copyin file ~a to ~a" store-dir dir)
        (uiop:run-program (list "rsync" "-av" (namestring (path:catdir store-dir "current/"))
                                (namestring out-current))
                          :output :interactive
                          :error-output :interactive)
        (assert (path:-d out-current))
        (make-instance 'safe-mp-store
                        :directory dir
                        :subsystems (store-subsystems))
        (log:info "Got ~d objects" (length (bknr.datastore:all-store-objects)))
        (log:info "Success!")))))

(defun parse-timetag (timetag)
  "timetag is what bknr.datastore calls it. See utils.lisp in
  bknr. This function converts the timetag into a valid timestamp."
  (multiple-value-bind (full parts)
      (cl-ppcre:scan-to-strings
       "(\\d\\d\\d\\d)(\\d\\d)(\\d\\d)T(\\d\\d)(\\d\\d)(\\d\\d)"
       timetag)
    (when full
     (apply #'local-time:encode-timestamp
            0 ;; nsec
            (reverse
             (loop for x across parts
                   collect (parse-integer x)))))))

(defun all-snapshots-sorted (dir)
  (let ((list (directory "/data/arnold/object-store/")))
    ;; remove any directories that don't look like timestamps
    (let ((list
            (loop for x in list
                  for dir-name = (car (last (pathname-directory x)))
                  for ts = (parse-timetag dir-name)
                  if ts
                    collect (cons ts x))))
      (sort
       list
       #'local-time:timestamp>
       :key 'car))))


(defun delete-snapshot-dir (dir)
  (assert (path:-d dir))
  (log:info "Deleting snapshot dir: ~a" dir)
  (fad:delete-directory-and-files dir))

(defun delete-old-snapshots ()
  ;; always keep at least 7 snapshots even if they are old
  (loop for (ts . dir) in (nthcdr 7 (all-snapshots-sorted (object-store)))
        if (local-time:timestamp< ts (local-time:timestamp- (local-time:now)
                                                            1 :month))
          do
             (delete-snapshot-dir dir)))


(defun cron-snapshot ()
  (when (boundp 'bknr.datastore:*store*)
    (log:info "Snapshotting bknr.datastore")
    (snapshot)))

(cl-cron:make-cron-job 'cron-snapshot
                        :minute 0
                        :hour 6
                        :hash-key 'cron-snapshot)

(cl-cron:make-cron-job 'delete-old-snapshots
                       :minute 0
                       :hour 4
                       :hash-key 'delete-old-snapshots)

(defun build-hash-table (objects slot &key test unique-index-p)
  (let ((hash-table (make-hash-table :test test)))
    (loop for obj in objects
          if (slot-boundp obj slot)
            do
               (let ((slot-value (slot-value obj slot)))
                 (assert (not (eql :png slot-value)))
                 (cond
                   (unique-index-p
                    (when slot-value
                      (setf (gethash slot-value hash-table)
                            obj)))
                   (t
                    (when slot-value
                     (push obj (gethash slot-value hash-table)))))))
    hash-table))

(defun find-effective-slot (class slot-name)
  (loop for slot in (closer-mop:class-slots class)
        if (eql slot-name (closer-mop:slot-definition-name slot))
          return slot
        finally (error "could not find slot")))

(defun atomp (x)
  (or
   (null x)
   (not (listp x))))

(defun hash-set-difference (left right &key test)
  "Similar to set-"
  (let ((table (make-hash-table :test test)))
    (dolist (x left)
      (setf (gethash x table) t))
    (dolist (x right)
      (remhash x table))
    (alexandria:hash-table-keys table)))

(defun unordered-equalp (list1 list2 &key (test #'eql))
  (declare (optimize (debug 3)))
  (cond
    ((and (atomp list1)
          (atomp list2))
     (equal list1 list2))
    ((or (atomp list1)
         (atomp list2))
     ;; this could also be the case that one of the lists are nil, but
     ;; it's correct to send false in that case.
     nil)
    (t
     (log:info "First list has ~d, and second list has ~d elements"
               (length list1)
               (length list2))
     (and
      (eql nil (hash-set-difference list1 list2 :test test))
      (eql nil (hash-set-difference list2 list1 :test test))))))

(defun assert-hash-tables= (h1 h2)
  (unless (eql (hash-table-test h1)
               (hash-table-test h2))
    (error "the two hash tables have different test functions"))
  (unless (unordered-equalp
           (alexandria:hash-table-keys h1)
           (alexandria:hash-table-keys h2)
           :test (hash-table-test h1))
    (error "The two hash tables have different keys"))
  (loop for k being the hash-keys of h1
        for value1 = (gethash k h1)
        for value2 = (gethash k h2)
        unless (unordered-equalp  value1 value2)
          do (error "the two hash tables have different values for key ~a" k)))

(defun validate-class-index (class-name slot-name)
  (declare (optimize (debug 3)))
  (log:info "Testing ~a, ~a" class-name slot-name)
  (restart-case
      (let* ((class (find-class class-name))
             (slot (find-effective-slot class slot-name))
             (indices (bknr.indices::index-effective-slot-definition-indices slot)))
        (unless (= 1 (length indices))
          (restart-case
              (error
                      "There are multiple indices for this slot (~a, ~a), probably an error: ~a"
                      class-name
                      slot-name
                      indices)
            (set-the-index-to-the-first-index ()
              (setf (bknr.indices::index-effective-slot-definition-indices slot)
                    (list (car indices))))
            (Continue-using-the-first-index
              (values))))
        (let*  ((index (car indices))
                (unique-index-p (typep index 'bknr.indices:unique-index)))
          (let* ((hash-table (bknr.indices::slot-index-hash-table index))
                 (test (hash-table-test hash-table))
                 (all-elts (store-objects-with-class class-name))
                 (new-hash-table (build-hash-table all-elts
                                                   slot-name
                                                   :test test
                                                   :unique-index-p unique-index-p)))
            (restart-case
                (progn
                  (log:info "Total number of elements: ~d" (length all-elts))
                  (assert-hash-tables= hash-table
                                       new-hash-table))
              (fix-the-index ()
                (setf (bknr.indices::slot-index-hash-table index)
                      new-hash-table))
              (continue-testing-other-indices ()
                (values))
))))
    (retry--validate-class-index ()
      (validate-class-index class-name slot-name))))


(defun validate-indices ()
  (let* ((objects (bknr.datastore:all-store-objects))
         (classes (remove-duplicates (mapcar 'class-of objects))))
    (log:info "Got ~a objects and ~a classes"
              (length objects)
              (length classes))
    (loop for class in classes
          do
          (loop for direct-slot in (closer-mop:class-direct-slots class)
                for slot-name = (closer-mop:slot-definition-name direct-slot)
                for slot = (find-effective-slot class slot-name)
                if (bknr.indices::index-direct-slot-definition-index-type direct-slot)
                if (not (eql 'bknr.datastore::id slot-name))
                  do
                     (let ((indices (bknr.indices::index-effective-slot-definition-indices slot)))
                       (assert indices)
                       (validate-class-index (class-name class)
                                            slot-name))))
    t))

;; (validate-indices)
