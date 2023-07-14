;;;; alphastrike.lisp

(in-package #:alphastrike)
(defparameter *here* (asdf:system-source-directory :alphastrike))

(defvar *layout* (make-layout :hex-to-pixel-matrix (vector (/ 3.0 2.0) 0 (/ (sqrt 3.0) 2.0) (sqrt 3.0))
                              :pixel-to-hex-matrix (vector (/ 2.0 3.0) 0 (/ 1.0 3.0) (/ (sqrt 3.0) 3.0))
                              :start-angle 0
                              :x-size 35
                              :y-size 35
                              :x-origin 10
                              :y-origin 10))

(defvar *locust*)
(defvar *phawk*)

(defvar *test-map* (make-instance 'grid))

(defun load-data ()
  "Load the contents of the data directory in prepration for execution."
  (uiop:chdir *here*)

  (let ((mech-files (uiop:directory-files (uiop:merge-pathnames* #p"data/units/" *here*))))
    (dolist (file mech-files)
      (if (string= (pathname-type file) "lisp") (load file)))))

(define-application-frame alphastrike ()
  ((active-unit
    :initform nil
    :accessor active-unit))
  (:menu-bar nil)
  (:panes
     (world
      :application
      :default-view +graphical-view+
      :display-function #'display-map)
     (record-sheet
      :application
      :display-function #'display-element)
     (menu :command-menu)
     ;;(int :interactor)
     )
  (:layouts
   (:default
    (vertically ()
      (:fill
       (horizontally ()
         (:fill world)
         (1/4 record-sheet)))
      (1/10 (vertically () menu))))))

(defmethod display-map ((frame alphastrike) stream)
  (maphash (lambda (k v)
             (present v 'tile))
           (tiles *test-map*))
  (let ((stream stream))
    (run-draw-units))
  )

(defmethod display-element ((frame alphastrike) stream)
  (unit-detail stream *locust*)
  (terpri stream)
  (unit-detail stream *phawk*)
  (terpri stream)
  (quickstats-block stream *locust*)
  (terpri stream)
  (quickstats-block stream *phawk*))

(define-alphastrike-command (com-damage-unit :name "Damage")
  ((target 'combat-unit
           :prompt "Target: ")
   (damage 'integer
           :default 1
           :prompt "Amount: "))
  (take-damage target damage))

(define-alphastrike-command (com-reset :name "Reset" :menu t)
  ((target 'combat-unit
           :prompt "Target: "))
  (setf (damageable/cur-armor target) (damageable/max-armor target))
  (setf (damageable/cur-struct target) (damageable/max-struct target)))

(define-alphastrike-command (com-measure-range :name "Measure Range" :menu t)
  ((origin 'combat-unit)
   (target 'tile))
  (notify-user *application-frame*
               (format nil "Range: ~d" (hex-distance (new-hexagon :q (location/q origin)
                                                                  :r (location/r origin)
                                                                  :s (location/s origin))
                                                     (tile-hexagon target)))))

(define-alphastrike-command (com-command-move-unit :name "Move" :menu t)
  ((unit 'combat-unit)
   (destination 'tile))
  (move-unit unit destination))

(define-alphastrike-command (com-command-attack :name "Attack" :menu t)
  ((attacker 'combat-unit)
   (target 'combat-unit))
  (make-attack attacker target))

(define-alphastrike-command (com-roll :name "Roll" :menu t)
  ()
  (notify-user *application-frame* (format nil "Rolled a ~d on 2D6." (roll2d))))

(define-alphastrike-command (com-select-unit :name "Select")
  ((selected 'combat-unit))
  (setf (active-unit *application-frame*) selected))

(define-alphastrike-command (com-quit-game :name "Quit Game" :menu t)
  ()
  (frame-exit *application-frame*))

;; (define-presentation-to-command-translator tile-selector
;;     (tile com-inspect-tile alphastrike :gesture :select)
;;     (object)
;;   (list object))

(define-presentation-to-command-translator unit-selector
    (combat-unit com-select-unit alphastrike :gesture :select)
    (object)
  (list object))


(defun main ()
  ;;(load-data)
  (load-board-file #P"data/boards/16x17 Grassland 1.board" *test-map*)
  (load-data)
  (setf *locust* (locust-lct-1v))
  (setf (location/q *locust*) 1)
  (setf (location/r *locust*) 1)
  (setf (location/s *locust*) -2)
  (setf (damageable/crit-list *locust*) '())
  (setf (pilot/name *locust*) "Shooty McPilotface")
  (setf (pilot/skill *locust*) 4)
  (setf *phawk* (phoenix-hawk-pxh-1d))
  (setf (location/q *phawk*) 8)
  (setf (location/r *phawk*) 5)
  (setf (location/s *phawk*) -13)
  (setf (damageable/crit-list *phawk*) '())
  (setf (pilot/name *phawk*) "Drivey McShooterface")
  (setf (pilot/skill *phawk*) 4)
  (run-frame-top-level
   (make-application-frame 'alphastrike
                           :width 800
                           :height 800)))
