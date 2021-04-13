#lang racket/base

(provide (all-defined-out))

(require scribble/base)
(require scriblib/autobib)

(define-cite ~cite citet generate-bibliography
  #:style number-style)
  ;; #:style author+date-square-bracket-style)

(define knuth-art
  (make-bib #:title "The Art of Computer Programming"
            #:author (authors "Donald Knuth")
            #:date 2005
            #:location (book-chapter-location "The Art of Computer Programming"
                        #:pages (list 319 354)
                        #:volume "4A"
                        #:publisher "Addison-Wesley")
            #:is-book? #t
            #:note "Volume 4A"
            ))

(define wiki-tabu
  (make-bib #:title "Wikipedia: The Tabu Algorithm"
            #:author (authors "Wikipedia")
            #:date 2021
            #:url "https://en.wikipedia.org/w/index.php?title=Tabu_search&oldid=1006854633"))

(define wiki-asteroids
  (make-bib #:title (elem "Wikipedia: " (italic "Asteroids") " (video game)")
            #:author (authors "Wikipedia")
            #:date 2021
            #:url "https://en.wikipedia.org/w/index.php?title=Asteroids_(video_game)&oldid=1016830718"))
