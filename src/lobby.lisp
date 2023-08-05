(in-package :megastrike)

(defclass lobby ()
  ((selected-mek  :initform nil :accessor lobby/selected-mek)
   (game          :initform nil :accessor lobby/game
                  :initarg :game)))
(defun new-lobby ()
  (let ((g (new-game)))
    (make-instance 'lobby :game g)))

(defun draw-lobby-screen (window)
  (let ((layout (make-instance 'gtk-grid
                               :name "lobby"
                               :hexpand t
                               :vexpand t
                               :column-spacing 15
                               :row-spacing 15))
        (map-selection (draw-map-selection))
        (force-setup (draw-force-setup window))
        (unit-selection (draw-unit-selection))
        (unit-list (draw-unit-list)))
    (gtk-grid-attach layout map-selection  0 0 1 1)
    (gtk-grid-attach layout unit-selection 1 0 1 1)
    (gtk-grid-attach layout force-setup    0 1 1 1)
    (gtk-grid-attach layout unit-list      1 1 1 1)
    (gtk-container-add window layout)
    (gtk-widget-show-all window)))

(defun draw-map-selection ()
  (let ((layout (make-instance 'gtk-grid))
        (title (make-instance 'gtk-label
                              :use-markup t
                              :label "<big>Map Selection</big>"))
        (width-label (make-instance 'gtk-label
                                    :use-markup t
                                    :label "<b>Map Width: </b>"))
        (width-entry (make-instance 'gtk-entry
                                     :width-chars 10))
        (height-label (make-instance 'gtk-label
                                    :use-markup t
                                    :label "<b>Map Width: </b>"))
        (height-entry (make-instance 'gtk-entry
                                     :width-chars 10))
        (create-button (gtk-button-new-with-label "Create Map")))
    (g-signal-connect create-button "clicked"
                      (lambda (widget)
                        (declare (ignore widget))
                        (let ((w (parse-integer (gtk-entry-text width-entry)))
                              (h (parse-integer (gtk-entry-text height-entry))))
                          (if (and w h)
                              (setf (game/board *game*) (make-grid w h))))))
    (gtk-grid-attach layout title 0 0 2 1)
    (gtk-grid-attach layout width-label 0 1 1 1)
    (gtk-grid-attach-next-to layout width-entry width-label :right 1 1)
    (gtk-grid-attach layout height-label 0 2 1 1)
    (gtk-grid-attach-next-to layout height-entry height-label :right 1 1)
    (gtk-grid-attach layout create-button 0 3 1 1)
    layout))

;; This `let' establishes all the column names needed for the force list view.
(let ((col-force-name 0) (col-force-color 1) (col-force-deployment 2)
      (col-force-pv 3) (model nil) (view nil))

  (defun build-force-model ()
    (let ((model (make-instance 'gtk-list-store
                                :column-types '("gchararray" "gchararray" "gchararray"
                                                "gint"))))
      (dolist (f (game/forces *game*))
        (let ((iter (gtk-list-store-append model)))
          (gtk-list-store-set model
                              iter
                              (force/name f)
                              (gdk-rgba-to-string (force/color f))
                              (force/deployment f)
                              (force-pv f))))
      model))

  (defun add-new-force (force)
    (gtk-list-store-set model
                        (gtk-list-store-append model)
                        (force/name force)
                        (gdk-rgba-to-string (force/color force))
                        (force/deployment force)
                        (force-pv force)))

  (defun update-forces ()
    (setf model nil)
    (build-force-model))

  (defun build-force-view ()
    (let ((view (gtk-tree-view-new-with-model model)))
      (let* ((renderer (gtk-cell-renderer-text-new))
             (column (gtk-tree-view-column-new-with-attributes "Name"
                                                               renderer
                                                               "text"
                                                               col-force-name)))
        (gtk-tree-view-append-column view column))
      (let* ((renderer (gtk-cell-renderer-text-new))
             (column (gtk-tree-view-column-new-with-attributes "Color"
                                                               renderer
                                                               "text"
                                                               col-force-color)))
        (gtk-tree-view-append-column view column))
      (let* ((renderer (gtk-cell-renderer-text-new))
             (column (gtk-tree-view-column-new-with-attributes "Deployment Zone"
                                                               renderer
                                                               "text"
                                                               col-force-deployment)))
        (gtk-tree-view-append-column view column))
      (let* ((renderer (gtk-cell-renderer-text-new))
             (column (gtk-tree-view-column-new-with-attributes "PV"
                                                               renderer
                                                               "text"
                                                               col-force-pv)))
        (gtk-tree-view-append-column view column))
      view))

  (defun draw-force-setup (window)
    (let* ((layout (make-instance 'gtk-box
                                  :orientation :vertical
                                  :spacing 10
                                  :homogenous t))
           (title (make-instance 'gtk-label
                                 :use-markup t
                                 :label "<big>Force Setup</big>"))
           (force-builder-row (make-instance 'gtk-box
                                             :orientation :horizontal
                                             :spacing 10))
           (new-force-label (make-instance 'gtk-label
                                           :label "Force Name: "))
           (new-force-entry (make-instance 'gtk-entry
                                           :width-chars 20))
           (new-force-color (make-instance 'gtk-color-button
                                           :rgba (gdk-rgba-parse "Gold")))
           (new-deploy-label (make-instance 'gtk-label
                                            :label "Deployment Zone: "))
           (new-deploy-entry (make-instance 'gtk-entry
                                            :width-chars 20))
           (new-force-button (gtk-button-new-with-label "New Force")))
      (setf model (build-force-model))
      (setf view (build-force-view))
      (g-signal-connect new-force-color "color-set"
                        (lambda (widget)
                          (let ((rgba (gtk-color-chooser-get-rgba widget)))
                            (format t "Selected color is ~A~%"
                                    (gdk-rgba-to-string rgba)))))
      (g-signal-connect new-force-button "clicked"
                        (lambda (widget)
                          (declare (ignore widget))
                          (let ((name (gtk-entry-text new-force-entry))
                                (deploy (gtk-entry-text new-deploy-entry))
                                (color (gtk-color-button-rgba new-force-color)))
                            (if (and name deploy color)
                                (progn
                                  (add-force *game* (new-force name color deploy))
                                  (add-new-force (car (game/forces *game*))))))
                          (draw-lobby-screen window)))
      (let ((selection (gtk-tree-view-get-selection view)))
        (setf (gtk-tree-selection-mode selection) :single)
        (g-signal-connect selection "changed"
                          (lambda (object)
                            (let* ((view (gtk-tree-selection-get-tree-view object))
                                   (model (gtk-tree-view-model view))
                                   (iter (gtk-tree-selection-get-selected object))
                                   (name (gtk-tree-model-get-value model iter col-force-name)))
                              (setf (game/selected-force *game*)
                                    (car (member name (game/forces *game*)
                                                 :test #'same-force)))))))
      (gtk-box-pack-start layout title)
      (gtk-box-pack-start force-builder-row new-force-label)
      (gtk-box-pack-start force-builder-row new-force-entry)
      (gtk-box-pack-start force-builder-row new-force-color)
      (gtk-box-pack-start force-builder-row new-deploy-label)
      (gtk-box-pack-start force-builder-row new-deploy-label)
      (gtk-box-pack-start force-builder-row new-deploy-entry)
      (gtk-box-pack-start force-builder-row new-force-button)
      (gtk-box-pack-start layout force-builder-row)
      (gtk-box-pack-start layout view)
      layout)))

(defun draw-unit-list ()
  (let ((layout (make-instance 'gtk-grid))
        (title (make-instance 'gtk-label
                              :use-markup t
                              :label "<big>Unit List</big>")))
    (gtk-grid-attach layout title 0 0 1 1)
    layout))
