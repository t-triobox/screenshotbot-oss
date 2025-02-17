;;;; -*- coding: utf-8 -*-
;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defpackage :screenshotbot/replay/test-core
  (:use #:cl
        #:fiveam)
  (:import-from #:screenshotbot/replay/core
                #:remote-response
                #:guess-external-format
                #:*http-cache-dir*
                #:load-url-into
                #:url
                #:assets
                #:snapshot
                #:should-rewrite-url-p
                #:read-srcset
                #:push-asset
                #:rewrite-css-urls
                #:http-get)
  (:local-nicknames (#:a #:alexandria)))
(in-package :screenshotbot/replay/test-core)


(util/fiveam:def-suite)

(def-fixture state ()
  (tmpdir:with-tmpdir (tmpdir)
    (let ((*http-cache-dir* tmpdir))
      (cl-mock:with-mocks ()
       (&body)))))


(test url-rewriting
  (let ((css "foo {
background: url(https://google.com)
}"))
    (is
     (equal
      "foo {
background: url(shttps://google.com?f=1)
}"
      (rewrite-css-urls css (lambda (url)
                              (format nil "s~a?f=1" url))))))
    (let ((css "foo {
background: url('https://google.com')
}"))
    (is
     (equal
      "foo {
background: url(shttps://google.com?f=1)
}"
      (rewrite-css-urls css (lambda (url)
                              (format nil "s~a?f=1" url)))))))

(test read-srcset
  (is (eql nil (read-srcset " ")))
  (is (equal `(("foo" . "20w"))
             (read-srcset "foo 20w")))
  (is (equal `(("foo" . "20w"))
             (read-srcset "  foo    20w   ")))
  (is (equal `(("foo" . "20w")
               ("bar" . "30w"))
             (read-srcset "  foo    20w  ,bar 30w ")))
  (is (equal `(("foo" . "20w")
               ("bar,0" . "30w"))
             (read-srcset "  foo    20w  ,bar,0 30w "))))

(test should-rewrite-url-p
  (is-true (should-rewrite-url-p "https://foobar.com/foo"))
  (is-false (should-rewrite-url-p "moz-extension://foobar.com/foo")))


(test push-asset-is-correctly-cached
  (with-fixture state ()
   (tmpdir:with-tmpdir (tmpdir)
     (cl-mock:if-called 'dex:get
                        (lambda (url &rest args)
                          (values
                           (flexi-streams:make-in-memory-input-stream
                            #())
                           200
                           (make-hash-table :test #'equal))))

     (let* ((snapshot (make-instance 'snapshot :tmpdir tmpdir))
            (rand (random 10000000000))
            (font (format nil "https://screenshotbot.io/assets/fonts/metropolis/Metropolis-Bold-arnold.otf?id=~a" rand))
            (html (format nil "https://screenshotbot.io/?id=~a" rand)))

       (push-asset snapshot (quri:uri html) nil)
       (is (equal 1 (length (assets snapshot))))
       (push-asset snapshot (quri:uri font)  t)
       (is (equal 2 (length (assets snapshot))))
       (is (equal font
                  (url (car (Assets snapshot)))))
       (push-asset snapshot (quri:uri font)  t)

       (is (equal 2 (length (assets snapshot))))
       (push-asset snapshot (quri:uri html) nil)
       (is (equal 2 (length (assets snapshot))))
       (push-asset snapshot (quri:uri font)  t)
       (is (equal 2 (length (assets snapshot))))))))

(test happy-path-fetch-toplevel
  (with-fixture state ()
   (tmpdir:with-tmpdir (tmpdir)
     (cl-mock:if-called 'dex:get
                        (lambda (url &rest args)
                          (values
                           (flexi-streams:make-in-memory-input-stream
                            (flexi-streams:string-to-octets
                             "<html><body></body></html>"))
                           200
                           (make-hash-table :test #'equal))))

     (let ((snapshot (make-instance 'snapshot :tmpdir tmpdir)))
       (load-url-into snapshot (quri:uri "https://screenshotbot.io/") tmpdir))
          (let ((snapshot (make-instance 'snapshot :tmpdir tmpdir)))
            (load-url-into snapshot "https://screenshotbot.io/" tmpdir)))))

(test utf-8
  (with-fixture state ()
   (tmpdir:with-tmpdir (tmpdir)
     (cl-mock:if-called 'dex:get
                        (lambda (url &rest args)
                          (values
                           (flexi-streams:make-in-memory-input-stream
                            (flexi-streams:string-to-octets
                             "<html><body>©</body></html>"
                             :external-format :utf-8))
                           200
                           (a:plist-hash-table
                            `("content-type" "text/html; charset=utf-8")
                            :test #'equal))))

     (with-open-stream (content (http-get "https://example.com" :force-string t
                                                                :force-binary nil))
       (is (equal "<html><body>©</body></html>" (uiop:slurp-input-stream :string content))))
     (with-open-stream (content (http-get "https://example.com" :force-string t
                                                                :force-binary nil))
       (is (equal "<html><body>©</body></html>" (uiop:slurp-input-stream :string content)))))))

(test guess-external-format
  (flet ((make-info (content-type)
           (let ((map (make-hash-table :test #'equal)))
             (setf (gethash "content-type" map) content-type)
             (make-instance 'remote-response
                             :headers map))))
    (is (equal :utf-8
               (guess-external-format (make-info "text/html; charset=utf-8"))))
    (is (equal :utf-8
               (guess-external-format (make-info "text/html; charset=UTF-8"))))
    (is (equal :utf-8
               (guess-external-format (make-info "text/html; charset='utf-8' "))))))
