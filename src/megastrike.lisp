;;;; megastrike.lisp

(in-package #:megastrike)

(gtk:define-application (:name megastrike
                         :id "bennett.megastrike")
  (gtk:define-main-window (window (gtk:make-application-window :application gtk:*application*))
    (setf (gtk:window-title window) "Megastrike")
    (setf *game* (new-game))
    (setf *lobby* (make-instance 'lobby))
    (let ((prov (gtk:make-css-provider)))
      (gtk:css-provider-load-from-path prov (namestring (merge-pathnames "data/css/style.css" (asdf:system-source-directory :megastrike))))
      (gtk:style-context-add-provider-for-display (gdk:display-default) prov gtk:+style-provider-priority-application+))
    (setf (lobby/forces *lobby*) (create-string-list (make-hash-table :test #'equal)))
    (let ((box (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 5))
          (game-label (gtk:make-label :str "Megastrike: Alphastrike on the Computer"))
          (new-game-button (gtk:make-button :label "New Game"))
          (default-game-button (gtk:make-button :label "Launch Default Game"))
          (exit-button (gtk:make-button :label "Exit")))
      (gtk:connect new-game-button "clicked" (lambda (button)
                                               (declare (ignore button))
                                               (draw-lobby-screen)
                                               (gtk:window-destroy window)))
      (gtk:connect default-game-button "clicked" (lambda (button)
                                                   (declare (ignore button))
                                                   (draw-lobby-screen)
                                                   (gtk:window-destroy window)))
      (gtk:connect exit-button "clicked" (lambda (button)
                                           (declare (ignore button))
                                           (gtk:window-destroy window)))
      (gtk:box-append box game-label)
      (gtk:box-append box new-game-button)
      (gtk:box-append box default-game-button)
      (gtk:box-append box exit-button)
      (setf (gtk:window-child window) box)
    (unless (gtk:widget-visible-p window)
      (gtk:window-present window)))))

(defun start-game ()
  (setf (game/forces-hash *game*) (string-list/source (lobby/forces *lobby*))
        (game/board *game*) (lobby/map *lobby*)
        (game/current-phase *game*) 0)
  (do-phase)
  (draw-gameplay-window))

(defun draw-gameplay-window ()
  (let* ((window (gtk:make-application-window :application gtk:*application*))
         (layout (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 5))
         (box (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 3))
         (map-scroll (gtk:make-scrolled-window))
         (map-area (gtk:make-drawing-area))
         (clicker (gtk:make-gesture-click))
         (recordsheet (draw-recordsheets))
         (command-bar (build-command-bar window))
         (turn-order-label (gtk:make-label :str "")))
    (setf (gtk:window-child window) layout)
    (setf (gtk:drawing-area-content-width map-area) (* (* (board/width (game/board *game*))
                                                          (layout-x-size +default-layout+)) 2)
          (gtk:drawing-area-content-height map-area) (* (* (board/height (game/board *game*))
                                                           (layout-y-size +default-layout+)) 2)
          (gtk:drawing-area-draw-func map-area) (list (cffi:callback %draw-func)
                                                      (cffi:null-pointer)
                                                      (cffi:null-pointer)))
    (setf (gtk:scrolled-window-child map-scroll) map-area)
    (setf (gtk:widget-hexpand-p map-scroll) t
          (gtk:widget-vexpand-p map-scroll) t
          (gtk:widget-hexpand-p box) t
          (gtk:widget-vexpand-p box) t)
    (gtk:widget-add-controller map-area clicker)
    (gtk:connect clicker "pressed"
                 (lambda (handler presses x y)
                   (declare (ignore handler presses))
                   (let ((hex (pixel-to-hex (make-point x y) +default-layout+)))
                     (map-click-handler hex)
                     (format t "Clicked at ~a,~a,~a: ~a~%" (hexagon-q hex) (hexagon-r hex) (hexagon-s hex) (offset-from-hex hex)))))
    (setf (gtk:label-label turn-order-label) (print-initiative *game*))
    (gtk:box-append box map-scroll)
    (gtk:box-append box recordsheet)
    (gtk:box-append layout box)
    (gtk:box-append layout turn-order-label)
    (gtk:box-append layout command-bar)
    (let ((action (gio:make-simple-action :name "update-initiative"
                                          :parameter-type nil)))
      (gio:action-map-add-action gtk:*application* action)
      (gtk:connect action "activate"
                   (lambda (action param)
                     (declare (ignore action param))
                     (setf (gtk:label-label turn-order-label) (print-initiative *game*)))))
    (let ((action (gio:make-simple-action :name "next-phase"
                                          :parameter-type nil)))
      (gio:action-map-add-action gtk:*application* action)
      (gtk:connect action "activate"
                   (lambda (action param)
                     (declare (ignore action param))
                     (gtk:box-remove layout command-bar)
                     (setf command-bar (build-command-bar window))
                     (gtk:box-append layout command-bar)
                     (gtk:widget-queue-draw map-area))))
    (unless (gtk:widget-visible-p window)
      (gtk:window-present window))))

(defun build-command-bar (window)
  (let ((bar (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 5))
        (phase-label (gtk:make-label :str "Not Initialized")))
    (gtk:box-append bar phase-label)
    (let ((button (gtk:make-button :label "Next Phase")))
        (gtk:connect button "clicked"
                     (lambda (button)
                       (advance-phase)
                       (gtk:widget-activate-action button "app.next-phase" nil)))
        (gtk:box-append bar button))
    (when (= (game/current-phase *game*) 0)
      (setf (gtk:label-label phase-label) "Initiative Phase.")
      (let ((button (gtk:make-button :label "Reroll Initiative")))
        (gtk:connect button "clicked"
                     (lambda (button)
                       (do-initiative-phase)
                       (gtk:widget-activate-action button "app.update-initiative" nil)))
        (gtk:box-append bar button))
      )
    (when (= (game/current-phase *game*) 1)
      (setf (gtk:label-label phase-label) "Deployment Phase.")
      )
    (when (= (game/current-phase *game*) 3)
      (setf (gtk:label-label phase-label) "Movement Phase.")
      )
    (when (= (game/current-phase *game*) 4)
      (setf (gtk:label-label phase-label) "Combat Phase.")
      )
    (when (= (game/current-phase *game*) 5)
      (setf (gtk:label-label phase-label) "End Phase.")
      )
    (let ((button (gtk:make-button :label "Exit")))
          (gtk:connect button "clicked" (lambda (button)
                                      (declare (ignore button))
                                      (gtk:window-destroy window)))
          (gtk:box-append bar button))
    bar))

(declaim (ftype (function (t t t t) t) draw-func))

(cffi:defcallback %draw-func :void ((area :pointer)
                                    (cr :pointer)
                                    (width :int)
                                    (height :int)
                                    (data :pointer))
  (declare (ignore data))
  (let ((cairo:*context* (make-instance 'cairo:context
                                        :pointer cr
                                        :width width
                                        :height height
                                        :pixel-based-p nil)))
    (draw-func (make-instance 'gir::object-instance
                              :class (gir:nget gtk:*ns* "DrawingArea")
                              :this area)
               (make-instance 'gir::struct-instance
                              :class (gir:nget megastrike::*ns* "Context")
                              :this cr)
               width height)))

(defun draw-func (area cr width height)
  (declare (ignore area)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  ;; TODO let some scaling on the size of the picture
  (let ((width (coerce (the fixnum width) 'single-float))
        (height (coerce (the fixnum height) 'single-float))
        (fpi (coerce pi 'single-float)))
    (loop :for loc being the hash-keys of (board/tiles (game/board *game*))
          :for tile being the hash-values of (board/tiles (game/board *game*))
          :do (cairo-draw-hex loc tile cr))))

(defun cairo-draw-hex (loc hex cr)
  (let ((hex-points (draw-hex hex +default-layout+))
        (hex-center (hex-to-pixel hex +default-layout+))
        (unit (first (member hex (game/units *game*) :key #'cu/location :test #'same-hex))))
    (with-gdk-rgba (color "#009917")
        (cairo:move-to (point-x (first hex-points)) (point-y (first hex-points)))
        (dotimes (i 6)
          (cairo:line-to (point-x (nth i hex-points)) (point-y (nth i hex-points))))
        (cairo:close-path)
        (gdk:cairo-set-source-rgba cr color)
        (cairo:fill-preserve))
    (with-gdk-rgba (color "#000000")
        (gdk:cairo-set-source-rgba cr color)
        (cairo:stroke))
    (when unit
      (with-gdk-rgba (color "#000000")
        (let (m (cairo:create-pattern-for-surface (cu/display unit)))
          (gdk:cairo-set-source-rgba cr color)
          (gdk:cairo-set-source-pixbuf cr
                                       (gdk:pixbuf-get-from-texture (cu/display unit))
                                       (point-x (nth 5 hex-points))
                                       (point-y (nth 5 hex-points))))
        cairo:stroke))
    (with-gdk-rgba (color "#000000")
      (cairo:move-to (point-x (nth 3 hex-points)) (point-y (nth 3 hex-points)))
      (cairo:set-font-size 15)
      (cairo:text-path (format nil "~2,'0D~2,'0D" (first loc) (second loc)))
      (cairo:fill-path))))

(defun draw-round-report ()
  (let ((layout (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 5)))
    ))
