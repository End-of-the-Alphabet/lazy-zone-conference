#lang scribble/acmart @sigplan @nonacm[#t]
@(require scribble/core)
@(require scriblib/footnote)
@(require scriblib/figure)
@; First off, there is a scribble-mode for emacs
@; Second, this was helpful: https://prl.ccs.neu.edu/blog/2019/02/17/writing-a-paper-with-scribble/

@(define (exact . stuff)
   @; the style name "relax" puts a `\relax` no-op in front of the stuff
   (make-element (make-style "relax" '(exact-chars)) stuff))

@(define ($ . math-stuff)
   (apply exact (list "$" math-stuff "$")))

@(define ($$ . math-stuff)
   (apply exact (list "$$" math-stuff "$$")))

@;exact{\usepackage{cancel}}

@title{Wandering Down Forbidden Paths}
@subtitle{The Tabu Search and the Traveling Salesperson}
@author["Ashton Wiersdorf" #:email (email "ashton.wiersdorf@pobox.com")]
@author["Carter Wonnacott" #:email (email "carterdwonnacott@gmail.com")]
@author["Pierce Yeakley" #:email (email "pierceyeakley@gmail.com")]
@shortauthors{Wiersdorf, Wonnacott, Yeakley}

@abstract{
Finding an optimal solution to the Traveling Salesperson Problem runs in order @${O(n!)} with respect to the number of cities in the brute-force case. Taking advantage of dynamic programming and intelligent search can reduce this to @${O({n^2}2^n)}, but this remains exponential and entirely intractable for large problemsets. When a solution is needed, approximations can satsifice for our needs. In this paper we present one such optimzation, the Tabu Search, which shares many similarities to a local search algorithm.
}

@section{Introduction}

The Traveling Salesperson Problem is a classic problem in computer science with broad applications. Suppose a traveling salesperson desires to visit a number of cities, one after another. They would like to do so in the shortest amount of time, visit no city more than once, and to wind up back where they started. This problem crops up in not only a salesperson visiting cities, but in many other areas of logistics and manufacturing. This is in fact the exact problem that companies like UPS, FedEx, and Amazon have to solve to deliver packages efficiently. Another application that's more amusing than pressing is the problem of drawing the grpahics for the game @italic{Asteroids}: the original game was programmed on hardware that draws the asteroids' outlines direclty, rather than using a raster technique. Solving the optimum path for the drawing beam to follow is exactly the Traveling Salesperson Problem.

@figure-here["asteroids" "Author's mockup of the Asteroids game" (image "./resources/Asteroids_no_lines.png" #:scale 0.13)]

Unfortunately, the TSP explodes in complexity with the number of nodes to plot a route through. A brute-force algorithm that tries every combination would have @${O(n!)} different possibilities to sort through. Just to get an idea of how bad this complexity is, consider what would happen if you had an old arcade machine that played @italic{Asteroids}, and for the sake of this example, let's say that the machine can check 10000 possibilities per second, and that drawing is instantanious. We can compute the maxiumum frame rate @${fps} for some number of asteroids @${a} like so:

@$${
  fps(a) = \frac{1000}{n!}
}

If we start out with @${a = 5} asteroids, then we could theoretically have a frame rate of @${83.3\bar{3}} fps. If we shoot an asteroid and it breaks up into 3 smaller asteroids, now we have @${a = 7} and our frame rate drops to @${{\sim}1.984} fps, which is extremely noticable lag. As soon as we draw another bullet, say, then we have @${a = 8} and our frame rate drops to @${{\sim}0.248} fps, or roughly @emph{one frame every 4 seconds!} We didn't even take into account the cost of drawing the ship. The point is, each time you add just one more object to the set of nodes to traverse, the brute-force search space grows enormously.

This is completely unacceptable for for a video game. Indeed, solving the TSP for higher number of notes, such as might be useful for shipping companies, is well beyond our computational power. In many cases it's simpler to just start going down whatever seems to be the easiest path, and get to work.@note{There's a fun video about a man who reimplemented @italic{Asteroids} with a laser projecter: @url{https://youtu.be/FkHjG759ABY?t=683}. He explains how he uses a greedy approach.}

While the TSP as framed is concerned with simple euclidian distance, we can generalize the problem to a notion of @emph{cost}: instead of a simple scenario where the distance between two nodes is the same no matter which node you start from, an abstract cost function allows us to model asymetric relations or even one-way relations between connected cities.

In our paper, we examine a simple greedy algorithm, which usually performs much better than a dumb random solution, and a local-search algorithm called the Tabu search, which starts from the greedy algorithm and intelligently improves upon it.

@section{Greed is Acceptable}

One simple improvement over the brute-force method is a @emph{greedy} search technique: given a starting node, simply select the closest node that has not yet been visited. For a game of @italic{Asteroids}, this is probably going to be sufficient.

@figure-here["asteroids-path" @elem{Greedy route for drawing a frame of @italic{Asteroids}} (image "./resources/Asteroids_path_lines.png" #:scale 0.13)]

Greedy routes can give us decent solutions. They are @emph{not} guaranteed to be optimal, and can fail in otherwise simple cases.@note{Generated using the "Easy" setting with seed 909.}

@figure-here["suboptimal-greedy" @elem{With the right conditions, greedy solutions are not the best} (image "./resources/suboptimal_greedy.png" #:scale 0.3)]

@; FIXME: finish up here

@subsection[#:tag "greedy-algo"]{Algorithm Description}

Given a set of @${n} cities @${\{C\}}, find a path of cities @${c_1, c_2, \ldots, c_n}, encountered by greedily selecting the best next city not visited.

@; FIXME: Add greedy search algorithm

@section{Tabu Search: No Forbidden Paths}

Can we do better than greedy without spending all the effort to find an optimal solution? The Tabu List algorithm is a local search algorithm: from a starting state, the Tabu Search attempts to find better solutions living relatively nearby in the solution space to the TSP.

@subsection{Algorithm Description}

Given a set of @${n} cities @${\{C\}}, find a path of cities @${c_1, c_2, \ldots, c_n}, such that @${\sum_{i=1}^{n} cost(c_i, c_{i+1})} is minimized within a given running time.

@itemlist[#:style 'ordered
  @item{@exact{[Initilize.]} Initilize a Tabu list @${T} to be the empty set, and a neighborhood definition as @${N} to be 3. (The initial neighborhood definition can be tweaked.) }
  @item{@exact{[Find a starting place.]} Run the Greedy Algorithm (@secref{greedy-algo}) and save the result as our initial path as @${P_{best}}. }
  @item{@exact{[]}}
  @item{@exact{[Update the best solution so far.]} Compare @${P_{best}} with the new result:
    @itemlist[#:style 'ordered
      @item{If @${P_{best} = result}, @${N \leftarrow N + 1} }
      @item{Otherwise, @${P_{best} \leftarrow result}}
    ]
  }
]

@section{Evaluation}


@section{Formal Analysis}


@section{Further Work}

