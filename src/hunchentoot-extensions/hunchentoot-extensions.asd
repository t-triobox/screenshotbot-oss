;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defsystem :hunchentoot-extensions
  :serial t
  :depends-on (:hunchentoot
               :str
               :markup
               :quri
               :do-urlencode
               :log4cl)
  :components ((:file "package")
               (:file "url")
               (:file "acceptor-with-plugins")
               (:file "better-easy-handler")))

(defsystem :hunchentoot-extensions/tests
  :serial t
  :depends-on (:hunchentoot-extensions
               :fiveam)
  :components ((:file "test-acceptor-with-plugins")
               (:file "test-better-easy-handler")
               (:file "test-url")))
