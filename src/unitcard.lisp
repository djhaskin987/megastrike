(in-package :megastrike)

(defun draw-recordsheets ()
  (let* ((layout (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 15))
         (current-team (nth (game/initiative-place *game*) (game/initiative-list *game*)))
         (other-team (car (remove-if #'(lambda (f) (string= current-team f))
                                     (game/initiative-list *game*)
                                     :start (game/initiative-place *game*))))
         (cur-team-label (gtk:make-label :str ""))
         (cur-team-scroll (gtk:make-scrolled-window))
         (cur-team-record-sheets (gtk:make-list-box))
         (other-team-label (gtk:make-label :str ""))
         (other-team-scroll (gtk:make-scrolled-window))
         (other-team-record-sheets (gtk:make-list-box)))
    (gtk:box-append layout cur-team-label)
    (gtk:box-append layout cur-team-scroll)
    (setf (gtk:widget-vexpand-p cur-team-scroll) t
          (gtk:widget-hexpand-p cur-team-scroll) t
          (gtk:widget-vexpand-p cur-team-record-sheets) t
          (gtk:widget-hexpand-p cur-team-record-sheets) t
          (gtk:label-label cur-team-label) (format nil "~a Units" current-team))
    (setf (gtk:scrolled-window-child cur-team-scroll) cur-team-record-sheets)
    (gtk:connect cur-team-record-sheets "row-selected"
                 (lambda (lb row)
                   (declare (ignore lb))
                   (when row
                     (let* ((str (gtk:frame-label (gobj:coerce (gtk:list-box-row-child row) 'gtk:frame)))
                            (u (car (member str (game/units *game*) :key #'cu/full-name :test #'string=))))
                       (if (cu/actedp u)
                           (gtk:list-box-unselect-all lb)
                           (setf (game/active-unit *game*) u))))))
    (mapcar #'(lambda (u)
                (when (same-force (cu/force u) current-team)
                  (gtk:list-box-append cur-team-record-sheets (draw-stat-block u))))
            (game/units *game*))
    (gtk:box-append layout other-team-label)
    (gtk:box-append layout other-team-scroll)
    (setf (gtk:widget-vexpand-p other-team-scroll) t
          (gtk:widget-hexpand-p other-team-scroll) t
          (gtk:widget-vexpand-p other-team-record-sheets) t
          (gtk:widget-hexpand-p other-team-record-sheets) t
          (gtk:label-label other-team-label) (format nil "~a Units" other-team))
    (setf (gtk:scrolled-window-child other-team-scroll) other-team-record-sheets)
    (mapcar #'(lambda (u)
                (when (same-force (cu/force u) other-team)
                  (gtk:list-box-append other-team-record-sheets (draw-stat-block u))))
            (game/units *game*))
    layout))

(defun draw-quickstats (u)
  (let ((frame (gtk:make-frame :label (cu/full-name u)))
        (layout (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 5))
        (statblock (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 5))
        (gen-line (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 2))
        (nums-line (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 2))
        (picture (gtk:make-picture :paintable (gdk:make-texture :path (cu/display u))))
        (abilities-line (draw-abilities-line u)))
    (setf (gtk:frame-child frame) layout
          (gtk:widget-hexpand-p statblock) t
          (gtk:widget-vexpand-p statblock) t
          (gtk:widget-hexpand-p frame) t
          (gtk:widget-vexpand-p frame) t)
    (gtk:box-append layout picture)
    (gtk:box-append layout statblock)
    (gtk:box-append gen-line (gtk:make-label :str (format nil "Pilot: ~a" (print-pilot u))))
    (gtk:box-append gen-line (gtk:make-label :str (format nil "Sz: ~a" (cu/size u))))
    (gtk:box-append gen-line (gtk:make-label :str (format nil "PV: ~a" (cu/pv u))))
    (gtk:box-append gen-line (gtk:make-label :str (format nil "Force: ~a" (print-force u))))
    (gtk:box-append gen-line picture)
    (gtk:box-append statblock gen-line)
    (gtk:box-append nums-line (gtk:make-label :str (format nil "MV: ~a" (print-movement u))))
    (gtk:box-append nums-line (gtk:make-label :str (format nil "S/M/L/E: ~a" (cu/attack-string u))))
    (gtk:box-append nums-line (gtk:make-label :str (format nil "A/S: ~a" (cu/arm-struct u))))
    (gtk:box-append statblock nums-line)
    (gtk:box-append statblock abilities-line)
    frame))

(defun draw-stat-block (u)
  (let ((frame (gtk:make-frame :label (cu/full-name u)))
        (statblock (gtk:make-box :orientation gtk:+orientation-vertical+ :spacing 5))
        (info-line (draw-general-info-line u))
        (attack-line (draw-attack-line u))
        (heat-line (draw-heat-line u))
        (damage-line (draw-damage-line u))
        (abilities-line (draw-abilities-line u)))
    (gtk:box-append statblock info-line)
    (gtk:box-append statblock attack-line)
    (gtk:box-append statblock heat-line)
    (gtk:box-append statblock damage-line)
    (gtk:box-append statblock abilities-line)
    (setf (gtk:frame-child frame) statblock)
    (when (cu/actedp u)
      (gtk:widget-add-css-class frame "acted"))
    frame))

(defun draw-general-info-line (u)
  (let ((line (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 5))
        (type-label (gtk:make-label :str (format nil "Type: ~A" (mek/type (cu/mek u)))))
        (size-label (gtk:make-label :str (format nil "Size: ~A" (mek/size (cu/mek u)))))
        (tmm-label (gtk:make-label :str (format nil "TMM: ~A" (mek/tmm (cu/mek u)))))
        (move-label (gtk:make-label :str (format nil "Move: ~A" (print-movement (cu/mek u)))))
        (role-label (gtk:make-label :str (format nil "Role: ~A" (mek/role (cu/mek u)))))
        (pilot-label (gtk:make-label :str (format nil "Pilot: ~A" (display (cu/pilot u))))))
    (gtk:box-append line type-label)
    (gtk:box-append line size-label)
    (gtk:box-append line tmm-label)
    (gtk:box-append line move-label)
    (gtk:box-append line role-label)
    (gtk:box-append line pilot-label)
    line))

(defun draw-attack-line (u)
  (let ((line (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 5))
        (attack-label (gtk:make-label :str (cu/attack-string u))))
    (gtk:box-append line attack-label)
    line))



(defun draw-heat-line (u)
  (let ((line (gtk:make-box :orientation gtk:+orientation-horizontal+ :spacing 5))
        (ov-label (gtk:make-label :str (format nil "<b>OV:</b> ~a" (mek/ov (cu/mek u)))))
        (heat-label (gtk:make-label :str (format nil "<b>Current Heat:</b> ~a" (cu/cur-heat u))))
        (heat-level-bar (gtk:make-level-bar)))
    (setf (gtk:label-use-markup-p ov-label) t
          (gtk:label-use-markup-p heat-label) t)
    (setf (gtk:level-bar-mode heat-level-bar) gtk:+level-bar-mode-discrete+)
    (setf (gtk:level-bar-min-value heat-level-bar) 0d0
          (gtk:level-bar-max-value heat-level-bar) 4d0
          (gtk:level-bar-value heat-level-bar) (float (cu/cur-heat u) 0d0))
    (gtk:widget-add-css-class heat-level-bar "heat-bar")
    (gtk:box-append line ov-label)
    (gtk:box-append line heat-label)
    (gtk:box-append line heat-level-bar)
    line))

(defun draw-damage-line (u)
  (let ((frame (gtk:make-frame :label "Damage"))
        (layout (gtk:make-grid))
        (armor-label (gtk:make-label :str "Armor: "))
        (armor-level-bar (gtk:make-level-bar))
        (struct-label (gtk:make-label :str "Structure: "))
        (struct-level-bar (gtk:make-level-bar)))
    (setf (gtk:level-bar-min-value armor-level-bar) 0d0
          (gtk:level-bar-max-value armor-level-bar) (float (mek/armor (cu/mek u)) 0d0)
          (gtk:level-bar-min-value struct-level-bar) 0d0
          (gtk:level-bar-max-value struct-level-bar) (float (mek/structure (cu/mek u)) 0d0)
          (gtk:level-bar-mode armor-level-bar) gtk:+level-bar-mode-discrete+
          (gtk:level-bar-mode struct-level-bar) gtk:+level-bar-mode-discrete+
          (gtk:level-bar-value armor-level-bar) (float (cu/cur-armor u) 0d0)
          (gtk:level-bar-value struct-level-bar) (float (cu/cur-struct u) 0d0))
    (gtk:widget-add-css-class armor-level-bar "damage-bar")
    (gtk:widget-add-css-class struct-level-bar "damage-bar")
    (gtk:grid-attach layout armor-label 0 0 1 1)
    (gtk:grid-attach layout armor-level-bar 1 0 3 1)
    (gtk:grid-attach layout struct-label 0 1 1 1)
    (gtk:grid-attach layout struct-level-bar 1 1 3 1)
    (setf (gtk:frame-child frame) layout)
    frame))

(defun draw-abilities-line (u)
  (let ((abilities-label (gtk:make-label :str (format nil "Abilities: ~a" (mek/abilities (cu/mek u))))))
    abilities-label))
