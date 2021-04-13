#lang scribble/acmart @sigplan @nonacm[#t]
@(require scribble/core)
@(require scriblib/footnote)
@(require scriblib/figure)
@(require scriblib/bibtex)
@(require scriblib/autobib)
@; First off, there is a scribble-mode for emacs
@; Second, this was helpful: https://prl.ccs.neu.edu/blog/2019/02/17/writing-a-paper-with-scribble/

@(define-bibtex-cite "./resources/references.bib" ~cite citet generate-bibliography #:style number-style)

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
Finding an optimal solution to the Traveling Salesperson Problem runs in order @${O(n!)} with respect to the number of cities in the brute-force case. Taking advantage of dynamic programming and intelligent search can reduce this to @${O({n^2}2^n)}, but this remains exponential and entirely intractable for large problem sets. When a solution is needed, approximations can satisfice for our needs. In this paper we present one such optimization, the Tabu Search, which shares many similarities to a local search algorithm.
}

@section{Introduction}

The Traveling Salesperson Problem is a classic problem in computer science with broad applications. Suppose a traveling salesperson desires to visit a number of cities, one after another. They would like to do so in the shortest amount of time, visit no city more than once, and wind up back where they started. This problem crops up in not only a salesperson visiting cities, but in many other areas of logistics and manufacturing. This is, in fact, the exact problem that companies like UPS, FedEx, and Amazon have to solve to deliver packages efficiently. Another application that's more amusing than pressing is the problem of drawing the graphics for the game @italic{Asteroids}: the original game was programmed on hardware that draws the asteroids' outlines directly, rather than using a raster technique. Solving the optimum path for the drawing beam to follow is exactly the Traveling Salesperson Problem.

@figure-here["asteroids" "Author's mockup of the Asteroids game" (image "./resources/Asteroids_no_lines.png" #:scale 0.13)]

Unfortunately, the TSP explodes in complexity with the number of nodes to plot a route through. A brute-force algorithm that tries every combination would have @${O(n!)} different possibilities to sort through. Just to get an idea of how bad this complexity is, consider what would happen if you had an old arcade machine that played @italic{Asteroids}, and for the sake of this example, let's say that the machine can check 10000 possibilities per second, and that drawing is instantaneous. We can compute the maximum frame rate @${fps} for some number of asteroids @${a} like so:

@$${
  fps(a) = \frac{1000}{n!}
}

If we start out with @${a = 5} asteroids, then we could theoretically have a frame rate of @${83.3\bar{3}} fps. If we shoot an asteroid and it breaks up into 3 smaller asteroids, now we have @${a = 7} and our frame rate drops to @${{\sim}1.984} fps, which is extremely noticeable lag. As soon as we draw another bullet, say, then we have @${a = 8} and our frame rate drops to @${{\sim}0.248} fps, or roughly @emph{one frame every 4 seconds!} This isn't even taking into account the cost of drawing the ship. The point is, each time you add just one more object to the set of nodes to traverse, the brute-force search space grows enormously.

This is completely unacceptable for for a video game. Indeed, solving the TSP for higher number of notes, such as might be useful for shipping companies, is well beyond our computational power. In many cases it's simpler to just start going down whatever seems to be the easiest path, and get to work.@note{There's a fun video about a man who reimplemented @italic{Asteroids} with a laser projector: @url{https://youtu.be/FkHjG759ABY?t=683}. He explains how he uses a greedy approach.}

While the TSP as framed is concerned with simple euclidean distance, we can generalize the problem to a notion of @emph{cost}: instead of a simple scenario where the distance between two nodes is the same no matter which node you start from, an abstract cost function allows us to model asymmetric relations or even one-way relations between connected cities.

In our paper, we examine a simple greedy algorithm, which usually performs much better than a dumb random solution, and a local-search algorithm called the Tabu search, which starts from the greedy algorithm and intelligently improves upon it.

@section{Greed is Acceptable}

One simple improvement over the brute-force method is a @emph{greedy} search technique: given a starting node, simply select the closest node that has not yet been visited. For a game of @italic{Asteroids}, this is probably going to be sufficient.

@figure-here["asteroids-path" @elem{Greedy route for drawing a frame of @italic{Asteroids}} (image "./resources/Asteroids_path_lines.png" #:scale 0.13)]

Greedy routes can give us decent solutions. They are @emph{not} guaranteed to be optimal, and can fail in otherwise simple cases.@note{Generated using the "Easy" setting with seed 909.}

@figure-here["sub-optimal-greedy" @elem{With the right conditions, greedy solutions are not the best} (image "./resources/suboptimal_greedy.png" #:scale 0.3)]

Nevertheless, a greedy algorithm can yield a good enough solution for many cases, and there are algorithms that use a greedy approach to get a good starting point, and then they improve on it. Branch-and-bound is one such algorithm that can use a greedy solution to get an approximate solution and then prune solutions that are less good. The Tabu Search presented in this paper is another such algorithm.

@subsection[#:tag "greedy-algo"]{Algorithm Description}

Given a set of @${n} cities @${\{C\}}, find a path of cities @${c_1, c_2, \ldots, c_n}, encountered by greedily selecting the best next city not visited.

@itemlist[#:style 'ordered
  @item{@exact{[Initilize.]} Pick some starting city @${c}, and add it to your path @${p}.}
  @item{@exact{[Select closest neighbor.]} For each city in @${C} that is not in the path @${p}, find the city with the lowest cost from @${c}.}
  @item{@exact{[Recur.]} Add this city to the end of the path, and recur as if at 2.}
  @item{@exact{[Backtrack.]} If recurring does not yield a valid path, or this is the last city in the path, and there is no route back to the start city, fail.}
  @item{@exact{[Try a different path.]} If there are still more cities that you can try from @${c}, try those in order of increasing distance.}
  @item{@exact{[Give up.]} If no more cities are left, fail.}
]

@subsection[#:tag "greedy-analysis"]{Algorithm Analysis}

Step 1 runs once in @${O(1)} time. For step 2, we search the remaining cities and recur on each one until we have a full path. At each successive call, the set of cities to search gets smaller, but we have roughly a search problem order @${O(n)} called @${n} times, so this means this step is @${O(n^2)}. This dominates, so the entire complexity of the greedy algorithm is order @${O(n^2)}.

This is expected; this is just a depth-first search of our graph where we let the weights of the edges be the discriminant in determining which path to traverse next. It does not yield an optimal solution, but it is a quick-running polynomial-time algorithm that gets us some results better than just a random walk.

@section{Tabu Search: No Forbidden Paths}

Can we do better than greedy without spending all the effort to find an optimal solution? The Tabu List algorithm is a local search algorithm: from a starting state, the Tabu Search attempts to find better solutions living relatively nearby in the solution space to the TSP.

@subsection{Intuition}

@; TODO

@subsection{Algorithm Description}

Given a set of @${n} cities @${\{C\}}, find a path of cities @${c_1, c_2, \ldots, c_n}, such that @${\sum_{i=1}^{n} cost(c_i, c_{i+1})} is minimized within a given running time.

@itemlist[#:style 'ordered
  @item{@exact{[Initialize.]} Initialize a Tabu list @${T} to be the empty set, and a neighborhood definition as @${N} to be 3. (The initial neighborhood definition can be tweaked.) Set @${tabu\_limit} to some positive integer. This defines how many paths we remember as having been searched.}
  @item{@exact{[Find a starting place.]} Run the Greedy Algorithm (@secref{greedy-algo}) and save the result as our initial path as @${P_{best}}. }
  @; @item{@exact{[Prepare for mutation.]} }
  @item{@exact{[Mutate.]} Take a walk in the neighborhood:
    @itemlist[#:style 'ordered
    @item{@exact{[Split the path.]} Set @${(outside, inside) \leftarrow split(P_{best}, N)} where @tt{split :: [Cities] @${\rightarrow \mathbb{N} \rightarrow} ([Cities], [Cities])} returns list split at the @${N^{th}} element from the end. }
    @item{@exact{[Collect permutations.]} Let @${\pi} be the set of all permutations of @${inside}. Prepend @${outside} to each element of @${inside}. @${\pi} is now a list of paths nearby @${P_{best}} in our solution space. }
    @item{@exact{[Thin.]} Drop all elements of @${\pi} that appear in our tabu list @${T}.}
    @item{@exact{[Find the best mutation.]} For each path @${i} in @${\pi}, if @${cost(i) < cost(P_{best})}, set @${P_{best} \leftarrow i}.
      }
     @item{@exact{[Add path to tabu list.]} Add path @${i} to @${T}. If @${|T| > tabu\_limit}, drop enough elements of @${T} so that it's within our limit.}
    ]
  }
  @item{@exact{[Increase mutation rate?]} If @${P_{best}} has not changed, increase the mutation rate: @${N \leftarrow N + 1}.}
  @item{@exact{[Repeat?]} If we still have some time left, and @${N < |C|}, go back to 3.}
  @item{@exact{[Return best.]} If we're out of time, return @${P_{best}}.}
]

@subsection{Algorithm Analysis}

Step 1 takes @${O(1)} time to initialize the algorithm. Step 2 calls out to the Greedy algorithm (@secref{greedy-analysis}) which takes @${O(n^2)} time.

Step 3 is @${O(1)} if we choose our data structures correctly; a good implementation can just set pointers to subsets of an array appropriately and be done.

Steps 4 and 5 are a little trickier. First, we generate all the permuatations of a set. Knuth @~cite{knuth_art_2005} lists several algorithms; however, for smaller values of the neighborhood @${N}, a simple recursive solution should be sufficient. For the purposes of this analysis, we'll consider permutation creation @${O(N)}@note{@${N}, not @${n}: it's relative to the size of our neighborhood parameter.} and checking tabu list for set inclusion to be order @${O(1)}; a hash map may be used to implement quick insertion and deletion of set elements.

@section{Evaluation}

@; TODO

@section{Further Work}

@; TODO

@(generate-bibliography)
