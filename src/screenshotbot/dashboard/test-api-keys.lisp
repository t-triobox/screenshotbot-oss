;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(pkg:define-package :screenshotbot/dashboard/test-api-keys
    (:use #:cl
          #:alexandria
          #:fiveam
          #:../api-key-api)
  (:import-from #:./api-keys
                #:%api-key-page)
  (:import-from #:../factory
                #:test-user
                #:test-api-key
                #:*company*)
  (:import-from #:screenshotbot/installation
                #:installation
                #:*installation*))

(util/fiveam:def-suite)

(test simple-page-test
  (let ((*installation* (make-instance 'installation)))
   (%api-key-page :user (make-instance 'test-user
                                       :api-keys (list (make-instance 'test-api-key
                                                                      :key "foo"
                                                                      :secret "sdfsdfdfdfs")))
                  :company *company*)))
