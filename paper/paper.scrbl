#lang scribble/acmart @sigplan @nonacm[#t]
@(require scribble/core)
@(require scriblib/footnote)
@(require scriblib/figure)
@require{resources/references.rkt}
@; @(require scriblib/bibtex)
@; @(require scriblib/autobib)

@; First off, there is a scribble-mode for emacs
@; Second, this was helpful: https://prl.ccs.neu.edu/blog/2019/02/17/writing-a-paper-with-scribble/

@; @(define-bibtex-cite "./resources/references.bib" ~cite citet generate-bibliography #:style number-style)

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

The Traveling Salesperson Problem is a classic problem in computer science with broad applications. Suppose a traveling salesperson desires to visit a number of cities, one after another. They would like to do so in the shortest amount of time, visit no city more than once, and wind up back where they started. This problem crops up in not only a salesperson visiting cities, but in many other areas of logistics and manufacturing. This is, in fact, the exact problem that companies like UPS, FedEx, and Amazon have to solve to deliver packages efficiently. Another application that's more amusing than pressing is the problem of drawing the graphics for the game @italic{Asteroids}: the original game was programmed on hardware that draws the asteroids' outlines directly, rather than using a raster technique. @~cite[wiki-asteroids] Solving the optimum path for the drawing beam to follow is exactly the Traveling Salesperson Problem.

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

Can we do better than greedy without spending all the effort to find an optimal solution? The Tabu List @~cite[wiki-tabu] algorithm is a local search algorithm: from a starting state, the Tabu Search attempts to find better solutions living relatively nearby in the solution space to the TSP.

@subsection{Intuition}

In layman’s terms, the tabu algorithm takes a previously found path, in this case from the solution of the greedy algorithm we implemented, and attempts to improve upon said solution. It does this by taking a certain number of items found at the end of the path array, finds every permutation---all possible combinations of the final items---reinserts each permutation into the first array segment, and checks the cost of each new path for all created permutations. If a new path is better, i.e lower in cost, then it will now become the current best solution.

@figure-here["greedy-segment" "Example of sub-optimal path from greedy search" (image "./resources/non-optimal-detail.png" #:scale 0.5)]

@figure-here["better-segment" "Same segment after better permutation of the cities found by Tabu Search" (image "./resources/optimal-detail.png" #:scale 0.5)]

The starting number of items partitioned at the back is generally arbitrary, but we started at three because it is the smallest number of path items that could be rearranged for which the greedy algorithm would not have already found a better solution. If no new solution was found the window size would be increased by one. This process may continue until the time limit is reached.

@subsection{Algorithm Description}

Given a set of @${n} cities @${\{C\}}, find a path of cities @${c_1, c_2, \ldots, c_n}, such that @${\sum_{i=1}^{n} cost(c_i, c_{i+1})} is minimized within a given running time.

@itemlist[#:style 'ordered
  @item{@exact{[Initialize.]} Initialize a Tabu list @${T} to be the empty set, and a neighborhood definition as @${N} to be 3. (The initial neighborhood definition can be tweaked.) Set @${tabu\_limit} to some positive integer. This defines how many paths we remember as having been searched.}
  @item{@exact{[Find a starting place.]} Run the Greedy Algorithm (@secref{greedy-algo}) and save the result as our initial path as @${P_{best}}. }
  @; @item{@exact{[Prepare for mutation.]} }
  @item{@exact{[Mutate.]} Take a walk in the neighborhood:
    @itemlist[#:style 'ordered
    @item{@exact{[Flip some cities.]} Swap @${N} pairs of cities. Discard any routes that appear in the tabu list @${T}.}
    @item{@exact{[Find the best mutation.]} While creating the mutations, keep track of the best one found in @${P_{best}}. Once you've done @${N} sets of @${N} swaps, return the best.}
    @item{@exact{[Add path to tabu list.]} Add each new path that's better than the current best to the tabu list @${T}. If @${|T| > tabu\_limit}, drop enough elements of @${T}, starting from the oldest, so that it's within our size limit.}
    ]
  }
  @item{@exact{[Increase mutation rate?]} If @${P_{best}} has not changed, increase the mutation rate: @${N \leftarrow N + 1}.}
  @item{@exact{[Repeat?]} If we still have some time left, and @${N < |C|}, go back to 3.}
  @item{@exact{[Return best.]} If we're out of time, return @${P_{best}}.}
]

@subsection{Algorithm Analysis}

Step 1 takes @${O(1)} time to initialize the algorithm. Step 2 calls out to the Greedy algorithm (@secref{greedy-analysis}) which takes @${O(n^2)} time.

For any given neighborhood size @${N}, step 3 runs roughly @${O(N^2)} times. If we assume efficient lookup, addition, and truncation of the Tabu list, (for example, by using a hash map where these operations take @${O(1)} time) then we get an overall complexity of @${O(N^2)} for this step.

Knuth @~cite[knuth-art] lists several algorithms for creating permutations; further work might investigate the effectiveness of choosing different permutations in the neighborhood.

Steps 4, 5, and 6 are variably adjustable: we can run these as long as we have time. This is one unique aspect of the Tabu search: we don't ever have to converge: we can keep running the algorithm indefinitely and allow it to explore the search space some more. Eventually we stop making improvements to our path, but even then we don't know whether or not we have an optimal solution.

@section{Empirical Evaluation}

@Figure-ref{results} is the table of results for running our algorithm against the random, greedy, branch-and-bound, and the Tabu Search.

@figure**["results" "Empirical results for Tabu search versus other algorithms"
@tabular[
	#:sep @hspace[2]
	#:column-properties '(left right)
	#:row-properties '(bottom-border)
	(list (list @bold{# Cities} @bold{Random} 'cont @bold{Greedy} 'cont 'cont @bold{Branch & Bound} 'cont 'cont @bold{Tabu Search} 'cont 'cont)
	      (list "" @smaller{Time (s)} @smaller{Path Length} @smaller{Time (s)} @smaller{Path Length} @smaller{% of Random} @smaller{Time (s)} @smaller{Path Length} @smaller{% of Greedy} @smaller{Time (s)} @smaller{Path Length} @smaller{% of Greedy})
	      (list "15" "0.0014" "19248" "0.001" "12134.2" "0.6304" "52.9764" "9800.2" "0.8076" "0.015" "11920" "0.9823")
	      (list "30" "0.0232" "34790.4" "0.01" "17705.6" "0.5089" "TB" "TB" "TB" "0.1966" "17469.6" "0.9866")
	      (list "60" "20.704" "81144.6" "0.0194" "27699.8" "0.3413" "TB" "TB" "TB" "3.1302" "27480.8" "0.9920")
	      (list "100" "TB" "TB" "0.0672" "44932.8" "TB" "TB" "TB" "TB" "40.2176" "37455" "0.8335" )
	      (list "200" "TB" "TB" "0.4308" "57153" "TB" "TB" "TB" "TB" "303.48" "56235" "0.9839" )
	      (list "500" "TB" "TB" "6.224" "104135.4" "TB" "TB" "TB" "TB" "607.1588" "103808.4" "0.9968" )
	      (list "750" "TB" "TB" "25.365" "136835.4" "TB" "TB" "TB" "TB" "629.9266" "136616.4" "0.9983" )
	)
]
]

Each of the results is the average of 5 successive runs. Each test was performed on the test harness's @tt{Hard} mode, which includes asymmetric and some infinite distances.

The results show that we were consistently able to get improvements over the standard greedy algorithm. However, further refinements may be warranted to derive full value from the Tabu algorithm. Nevertheless, this is a promising algorithm.

@section{Further Work}

There's a lot of interesting work that could be done with this algorithm. Some immediately apparent areas of interest include looking at the optimum number of cities to try swapping: swapping cities is a special case of a more generalized algorithm where we look at all permutations of some @${m} cities; this algorithm is effectively the case where @${m=2}.

Other areas of interest include refinements to the original search, changing where the swaps take place inside the path, etc. Different sizes of the Tabu list could also be used to get out of particular local optima. We suggest looking at these factors for any further work.

@section{Source Code}

For the source code used in this project, please see our GitHub repo: @url{https://github.com/End-of-the-Alphabet/lazy-zone-conference}

@(generate-bibliography)
