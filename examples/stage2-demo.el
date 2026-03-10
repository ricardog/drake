;;; stage2-demo.el --- Demo for Stage 2 features -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name (buffer-file-name)))))

(require 'drake)
(require 'drake-svg)

;; 1. Line plot with Hue and Alist-Rows
(let ((data '(((:year . 2010) (:sales . 100) (:region . "East"))
              ((:year . 2011) (:sales . 120) (:region . "East"))
              ((:year . 2012) (:sales . 150) (:region . "East"))
              ((:year . 2010) (:sales . 80)  (:region . "West"))
              ((:year . 2011) (:sales . 130) (:region . "West"))
              ((:year . 2012) (:sales . 110) (:region . "West")))))
  (drake-plot-line :data data :x :year :y :sales :hue :region :title "Sales Trends by Region" :buffer "*drake-line*"))

;; 2. Bar plot with Categorical X and Plist-Rows
(let ((data '((:fruit "Apple"  :count 50)
              (:fruit "Banana" :count 80)
              (:fruit "Cherry" :count 30))))
  (drake-plot-bar :data data :x :fruit :y :count :title "Fruit Counts" :buffer "*drake-bar*"))

;; 3. Scatter plot with Hue and Columnar Plist
(let ((data '(:x [1 2 3 4 5 6] 
              :y [10 15 13 18 20 25] 
              :species ("A" "A" "B" "B" "C" "C"))))
  (drake-plot-scatter :data data :x :x :y :y :hue :species :title "Species Distribution" :buffer "*drake-scatter*"))

(message "Demos rendered in *drake-line*, *drake-bar*, and *drake-scatter* buffers.")
