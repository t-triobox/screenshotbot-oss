;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defsystem :screenshotbot.sdk
  :author "Arnold Noronha <arnold@screenshotbot.io>"
  :license "Mozilla Public License, v 2.0"
  :serial t
  :depends-on (:dexador
               :com.google.flag
               :pkg
               :ironclad/core
               :hunchentoot
               :cl-json
               :log4cl
               :util/random-port
               :cl-store
               :cl-fad
               :cxml
               :zip
               :trivial-garbage
               :tmpdir
               :imago
               :imago/pngload
               :md5
               :screenshotbot/replay
               :dag
               :anaphora
               :str)
  :components ((:file "package")
               (:file "flags")
               (:file "bundle")
               (:file "android")
               (:file "git")
               (:file "help")
               (:file "sdk")
               (:file "static")
               (:file "main")))


(defsystem :screenshotbot.sdk/tests
  :serial t
  :depends-on (:screenshotbot.sdk
               :fiveam
               :screenshotbot
               :util/fiveam)
  :components ((:file "test-bundle")
               (:file "test-sdk")
               (:file "test-static")))
