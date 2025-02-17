;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(uiop:define-package :screenshotbot/test-diff-report
    (:use #:cl #:alexandria #:fiveam)
  (:import-from #:screenshotbot/model
                #:channel
                #:make-screenshot
                #:local-image
                #:recorder-run)
  (:import-from #:screenshotbot/diff-report
                #:diff-report
                #:diff-report-changes
                #:diff-report-changes
                #:make-diff-report
                #:diff-report-title))
(in-package :screenshotbot/test-diff-report)

(util/fiveam:def-suite)

(test 2-changed
  (is (equal "3 changes"
             (diff-report-title (make-instance 'diff-report :changes (list 1 2 3)))))
  (is (equal "3 changes, 1 deleted"
             (diff-report-title (make-instance 'diff-report :changes (list 1 2 3)
                                                            :deleted (list 1)))))
  (is (equal "3 changes, 1 added"
             (diff-report-title (make-instance 'diff-report :changes (list 1 2 3)
                                                            :added (list 1))))))

(test make-diff-report
  (let* ((img (make-instance 'local-image :url "/assets/images/example-view-square.svg.png"))
         (img2 (make-instance 'local-image :url "/assets/images/example-view.svg.png"))
         (channel (make-instance 'channel))
         (screenshot (make-screenshot :name "foo"
                                      :image img))
         (screenshot2 (make-screenshot :name "foo"
                                        :image img2))
         (run1 (make-instance 'recorder-run :screenshots (list screenshot)))
         (run2 (make-instance 'recorder-run :screenshots (list screenshot2))))
    (let ((diff-report (make-diff-report run1 run2)))
      (is (eql 1 (length (diff-report-changes diff-report)))))))
