;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defpackage :jvm
  (:use :cl
   :alexandria)
  (:export :jvm-init
           :*libjvm*))
(in-package :jvm)

#+lispworks
(eval-when (:compile-toplevel  :load-toplevel)
  (require "java-interface"))

(defun jvm-get-classpath ()
  (let ((class-path
          (build-utils:java-class-path (asdf:find-system :java.main))))
    #+ccl
    (pushnew (asdf:system-relative-pathname :cl+j "cl_j.jar")
             class-path)

    #+lispworks
    (pushnew
     (sys:lispworks-file "etc/lispcalls.jar")
     class-path)

    class-path))

(defvar *libjvm* nil
  "Configure with --libjvm")

(defun libjvm.so ()
  (or
   *libjvm*
   (let ((guesses (list
                   "/usr/lib/jvm/java-11-openjdk-amd64/lib/server/libjvm.so"
                   "/usr/lib/jvm/java-11-openjdk/lib/server/libjvm.so")))
     (loop for guess in guesses
           if (path:-e guess)
             do (return guess)
           finally
           (error "Could not find java or libjvm.so, pass --libjvm argument")))))

#+ccl
(defun jvm-init-for-ccl ()
  (setf cl-user::*jvm-path* (libjvm.so))
  (setf cl-user::*jvm-options*
        (list "-Xrs"
              (format nil "-Djava.class.path=~a"
                      (str:join ":" (mapcar 'namestring (jvm-get-classpath)))))))

(defun jvm-init ()
  #+lispworks
  (lw-ji:init-java-interface
   :java-class-path (jvm-get-classpath)
   :option-strings (list #+nil"-verbose")
   :jvm-library-path (libjvm.so))

  #+ccl
  (progn
    (jvm-init-for-ccl)
    (pushnew "local-projects/cl+j-0.4/" asdf:*central-registry*)
    (asdf:load-system :cl+j)
    (funcall (find-symbol "JAVA-INIT" "CL+J")))

  #+(and :lispworks (not :screenshotbot-oss))
  (lw-ji:find-java-class "io.tdrhq.TdrhqS3"))
