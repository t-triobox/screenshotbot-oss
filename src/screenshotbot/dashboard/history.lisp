;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(uiop:define-package :screenshotbot/dashboard/history
  (:use #:cl
        #:alexandria
        #:screenshotbot/user-api
        #:screenshotbot/report-api
        #:screenshotbot/template
        #:screenshotbot/screenshot-api)
  (:import-from #:screenshotbot/dashboard/run-page
                #:commit)
  (:import-from #:bknr.datastore
                #:store-object-with-id)
  (:import-from #:screenshotbot/server
                #:defhandler)
  (:import-from #:screenshotbot/dashboard/run-page
                #:history-page)
  (:import-from #:screenshotbot/taskie
                #:timeago)
  (:import-from #:util
                #:oid))
(in-package :screenshotbot/dashboard/history)


(markup:enable-reader)

(markup:deftag render-history (&key screenshots runs channel)
  <div class= "baguetteBox" >
    ,@ (loop for s in screenshots
    for r in runs
    collect
    (cond
    (s
    <div class= "mb-4" >
      <h4>,(screenshot-name s)</h4>

      ,(cond
         ((recorder-run-commit r)
          <p>First seen in <commit repo= (channel-repo channel)
                                   hash= (recorder-run-commit r) /></p>)
         (t
          <p>First seen <a href= (hex:make-url "/runs/:id" :id (oid r))>,(timeago :timestamp (created-at r))</a></p>))
      <a href= (image-public-url (screenshot-image s) :size :full-page) title= "Full screenshot">
        <img src=(image-public-url (screenshot-image s) :size :small) />
      </a>

    </div>)
    (t
     <div>
       <h4>Deleted</h4>
     </div>)))
  </div>)

(defhandler (history-page :uri "/channel/:channel/history")
            (channel screenshot-name)
  (let ((channel (store-object-with-id (parse-integer channel))))
    (can-view! channel)
    (multiple-value-bind (screenshots runs) (get-screenshot-history channel screenshot-name)
      (app-template
       (render-history
        :screenshots screenshots
        :channel channel
        :runs runs)))))
