#!/usr/bin/python3

from types import BuiltinFunctionType
from which_pyqt import PYQT_VER

if PYQT_VER == 'PYQT5':
    from PyQt5.QtCore import QLineF, QPointF
elif PYQT_VER == 'PYQT4':
    from PyQt4.QtCore import QLineF, QPointF
else:
    raise Exception('Unsupported Version of PyQt: {}'.format(PYQT_VER))

import copy
import time
import numpy as np
from Instrumenter import *
from TSPClasses import *
import heapq
import itertools


class TSPSolver:
    def __init__(self, gui_view):
        self._scenario = None

    def setupWithScenario(self, scenario):
        self._scenario = scenario

    ''' <summary>
        This is the entry point for the default solver
        which just finds a valid random tour.  Note this could be used to find your
        initial BSSF.
        </summary>
        <returns>results dictionary for GUI that contains three ints: cost of solution, 
        time spent to find solution, number of permutations tried during search, the 
        solution found, and three null values for fields not used for this 
        algorithm</returns> 
    '''

    def defaultRandomTour(self, time_allowance=60.0):
        results = {}
        cities = self._scenario.getCities()
        ncities = len(cities)
        foundTour = False
        count = 0
        bssf = None
        start_time = time.time()
        while not foundTour and time.time() - start_time < time_allowance:
            # create a random permutation
            perm = np.random.permutation(ncities)
            route = []
            # Now build the route using the random permutation
            for i in range(ncities):
                route.append(cities[perm[i]])
            bssf = TSPSolution(route)
            count += 1
            if bssf.cost < np.inf:
                # Found a valid route
                foundTour = True
        end_time = time.time()
        results['cost'] = bssf.cost if foundTour else math.inf
        results['time'] = end_time - start_time
        results['count'] = count
        results['soln'] = bssf
        results['max'] = None
        results['total'] = None
        results['pruned'] = None
        return results

    ''' <summary>
        This is the entry point for the greedy solver, which you must implement for 
        the group project (but it is probably a good idea to just do it for the branch-and
        bound project as a way to get your feet wet).  Note this could be used to find your
        initial BSSF.
        </summary>
        <returns>results dictionary for GUI that contains three ints: cost of best solution, 
        time spent to find best solution, total number of solutions found, the best
        solution found, and three null values for fields not used for this 
        algorithm</returns> 
    '''

    def greedy(self, time_allowance=60.0):
        inst = Instrumenter()
        cities = self._scenario.getCities()
        cities.sort(key=lambda c: c._index)

        start_time = time.time()
        start_state = bb_init_state(cities, cities[0])

        final_state = dfs_greedy(cities, start_state, inst)

        end_time = time.time()

        if not (final_state is None):
            return {'cost': get_cost_fp(state_path(final_state)),
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': TSPSolution(state_path(final_state)),
                    'max': inst.max_queue,
                    'total': inst.states_created,
                    'pruned': inst.states_pruned }
        else:
            return {'cost': float('inf'),
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': None,
                    'max': inst.max_queue,
                    'total': inst.states_created,
                    'pruned': inst.states_pruned }

    ''' <summary>
        This is the entry point for the branch-and-bound algorithm that you will implement
        </summary>
        <returns>results dictionary for GUI that contains three ints: cost of best solution, 
        time spent to find best solution, total number solutions found during search (does
        not include the initial BSSF), the best solution found, and three more ints: 
        max queue size, total number of states created, and number of pruned states.</returns> 
    '''

    def branchAndBound(self, time_allowance=60.0):
        inst = Instrumenter()

        start_time = time.time()

        final_state = strat_bb(self._scenario.getCities(), time_allowance, inst)

        end_time = time.time()

        if not (final_state is None):
            return {'cost': state_lb(final_state),
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': TSPSolution(state_path(final_state)),
                    'max': inst.max_queue,
                    'total': inst.states_created,
                    'pruned': inst.states_pruned}
        else:
            return {'cost': float('inf'),
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': None,
                    'max': inst.max_queue,
                    'total': inst.states_created,
                    'pruned': inst.states_pruned}

    ''' <summary>
        This is the entry point for the algorithm you'll write for your group project.
        </summary>
        <returns>results dictionary for GUI that contains three ints: cost of best solution, 
        time spent to find best solution, total number of solutions found during search, the 
        best solution found.  You may use the other three field however you like.
        algorithm</returns> 
    '''

    def fancy(self, time_allowance=60.0):
        inst = Instrumenter()

        start_time = time.time()
        cities = self._scenario.getCities()
        ncities = len(cities)

        city_dict = {}
        index_dict = {}
        start_indices = []
        final_cities = []

        print("populating dictionaries")
        for i in range(ncities):
            city_dict[cities[i]] = i
            index_dict[i] = cities[i]

        print("getting greedy solution")
        start_bssf = self.greedy().get('soln').route

        print("converting to integers")
        for city in start_bssf:
            start_indices.append(city_dict[city])

        final_state, path_cost = tabu_search(self._scenario.getCities(), time_allowance, inst, start_indices)

        for index in final_state:
            final_cities.append(index_dict[index])

        end_time = time.time()

        if not (final_state is None):
            return {'cost': path_cost,
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': TSPSolution(final_cities),
                    'max': 0,
                    'total': 0,
                    'pruned': 0}
        else:
            return {'cost': float('inf'),
                    'time': end_time - start_time,
                    'count': inst.solutions_found,
                    'soln': None,
                    'max': 0,
                    'total': 0,
                    'pruned':0}


tabu_list = []
tabu_limit = 500
cost_array = []


def tabu_search(cities, time_allowance, instrumenter, curr_bssf):
    # get cost array
    init_cost_array(cities)

    greedy_cost = get_cost(curr_bssf)

    # start search, end search when time runs out
    start_time = time.time()
    base_neighborhood_def = 3
    curr_neighborhood_def = base_neighborhood_def
    while time.time() - start_time < time_allowance:
        # TODO: use instrumenter
        old_bssf = curr_bssf
        curr_bssf = tabu_helper(curr_bssf, curr_neighborhood_def, start_time, time_allowance)
        if curr_bssf == old_bssf:
            curr_neighborhood_def += 1
            print(f"Neighborhood def now {curr_neighborhood_def}")
        else:
            curr_neighborhood_def = base_neighborhood_def
        if curr_neighborhood_def == len(cities):
            break

    best_cost = get_cost(curr_bssf)
    if greedy_cost < best_cost:
        i = "old is better"
    if greedy_cost > best_cost:
        i = "new is better"

    return curr_bssf, best_cost


'''
    :param path: array of integers representing cities
    :param neighborhood_def: int representing the definition of "neighborhood" in our local search
    
    :return updated_path: best path in the neighborhood
'''
def tabu_helper(path, neighborhood_def, start_time, time_allowance):
    # path is always our best path so far

    # outside_neighborhood: leave off the last `neighborhood_def` cities on path
    # inside_neighborhood: get the part that we trimmed off
    # so, let (outside, inside) (split-at-from-end path neighborhood_def)
    outside_neighborhood = path[:len(path) - neighborhood_def]
    inside_neighborhood = path[len(path) - neighborhood_def:]

    best_path = path

    for i in range(len(inside_neighborhood)):
        for j in range(i+1, len(inside_neighborhood)):
            if time.time() - start_time > time_allowance:
                return best_path

            inside_copy = inside_neighborhood.copy()
            old_i = inside_copy[i]
            inside_copy[i] = inside_copy[j]
            inside_copy[j] = old_i

            path = outside_neighborhood + inside_copy

            path_cost = get_cost(path)
            best_cost = get_cost(best_path)

            if path not in tabu_list and path_cost < best_cost:
                best_path = path
            tabu_list.append(path)
            if len(tabu_list) > tabu_limit:
                tabu_list.pop(0)

    return best_path


def get_cost(path):
    path_cost = 0
    for i in range(len(path)):
        j = (i + 1) % len(path)
        path_cost += cost_array[path[i]][path[j]]
    return path_cost

def get_cost_fp(path):
    path_cost = 0
    for i in range(len(path)):
        path_cost += cost(path[i], path[(i + 1) % len(path)])
    return path_cost


def init_cost_array(cities):
    for i in range(len(cities)):
        cost_row = []
        for j in range(len(cities)):
            cost_row.append(cities[i].costTo(cities[j]))
        cost_array.append(cost_row)


############################################################
#
#             Strategy: Branch-and-Bound
#
############################################################

# Type Definitions
# ---------
# Time :: time
# Instrument :: {max_queue:Nat, states_created:Nat, states_pruned:Nat}
# BbState :: (CostMatrix:[[Real]], LowerBound:Real, Depth:Nat, Path:[City])

# dfs_greedy :: [City] -> BbState -> Instrument -> Optional(BbState)
def dfs_greedy(cities, state, instrument):
    # pprint_state(state)

    path = state_path(state)
    if len(cities) == len(path):
        # Make sure we can go from start to end
        if cost(path[-1], path[0]) != float('inf'):
            return state
        else:
            return None
    else:
        next_cities = []
        for c in cities:
            if not c in state_path(state):
                next_cities.append(c)

        next_cities.sort(key=lambda x: cost(state_path(state)[-1], x))
        
        for c in next_cities:
            if cost(state_path(state)[-1], c) != float('inf'):
                (a1, a2, a3, a4) = state
                fs = dfs_greedy(cities, (a1, a2, a3+1, a4 + [c]), instrument)
                if not (fs is None):
                    return fs

        return None

def test_dfs_greedy():
    loc = [QPointF(0, 2), QPointF(2, 3), QPointF(3, 1), QPointF(1, -2), QPointF(-2, 0)]
    s = Scenario(loc, "", 0)
    cs = s.getCities()
    cs.sort(key=lambda i: i._index)

    st = bb_init_state(cs, cs[0])

    # ([[inf, 0,    926,  1110, 592],
    #   [0,   inf,  0,    2086, 2763],
    #   [926, 0,    inf,  592,  2863],
    #   [518, 1494, 0,    inf,  0],
    #   [0,   2171, 2271, 0,    inf]],
    #  13923, [])

    instrument = Instrumenter()
    fs = dfs_greedy(cs, st, instrument)
    assert not fs is None
    assert state_path(fs) == [cs[0], cs[1], cs[2], cs[3], cs[4]]
    assert instrument.states_created == 10

    # Ok, now try in a scenario where you cannot get from 5 to 1:
    instrument = Instrumenter()
    loc = [QPointF(0, 2), QPointF(2, 3), QPointF(3, 1), QPointF(1, -2), QPointF(-2, 0)]
    s = Scenario(loc, "", 0)
    cs = s.getCities()
    s._edge_exists[4, 0] = False
    assert cost(cs[4], cs[0]) == float('inf')
    cs.sort(key=lambda i: i._index)

    st = bb_init_state(cs, cs[0])
    assert st[0][4][0] == float('inf')
    # [[inf, 0,    926,  1110, 592],
    #  [0,   inf,  0,    2086, 2763],
    #  [926, 0,    inf,  592,  2863],
    #  [518, 1494, 0,    inf,  0],
    #  [inf, 2171, 2271, 0,    inf]],

    fs = dfs_greedy(cs, st, instrument)
    assert not fs is None
    assert state_path(fs) == [cs[0], cs[4], cs[3], cs[2], cs[1]]
    assert state_lb(fs) == cost(cs[0], cs[4]) + cost(cs[4], cs[3]) + cost(cs[3], cs[2]) + cost(cs[2], cs[1]) + cost(
        cs[1], cs[0])
    assert instrument.states_created == 10


# strat_bb :: [City] -> Time -> Instrument -> Optional(BbState)
def strat_bb(cities, time_allowance, instrumenter):
    cities.sort(key=lambda c: c._index)
    states = [bb_init_state(cities, cities[0])]

    instrumenter.update_queue(1)
    instrumenter.inc_states_created()

    start_time = time.time()
    bssf = None

    # Greedily search for an initial solution
    greedy_state = dfs_greedy(cities, states[0], instrumenter)
    if (greedy_state is None) or (state_lb(greedy_state) == float('inf')):
        print("Error: greedy search failed!")
        return None

    bssf = greedy_state
    # FIXME: update the lb on the greedy state

    # Now that we have a decent value for best search so far, we can
    # start our regular branch-and-bound search

    states = [heap_state_lb(s) for s in states]
    heapq.heapify(states)

    while still_timep(start_time, time_allowance) and len(states) > 0:
        instrumenter.update_queue(len(states))
        (_, st) = heapq.heappop(states)

        # Is this an end state? If so, update the bssf
        if (len(cities) == len(state_path(st))):
            print("Found a solution")

            final_cost = cost(state_path(st)[-1], state_path(st)[0])
            st = (st[0], st[1] + final_cost, st[2], st[3])
            if state_lb(st) < state_lb(bssf):
                print(f"New best solution found: {state_lb(st)}")
                instrumenter.inc_solutions_found()
                bssf = st

        # Look at the next states; prune any that are worse than the
        # bssf that we have
        else:
            next_states = gen_next_states(st, cities)

            if len(next_states) == 0:
                print("Found a solution that's worse than our best so far")

            for nst in next_states:
                instrumenter.inc_states_created()

                if state_lb(nst) > state_lb(bssf):
                    instrumenter.inc_states_pruned()
                else:
                    new_key = heap_score_state(nst, len(cities), state_lb(bssf))
                    heapq.heappush(states, (new_key, nst))

    instrumenter.inc_states_pruned(len(states))
    print(f"final path:")
    for s in state_path(bssf):
        print(s._index, end=", ")
    print()

    # Let's verify that our solution is correct
    # total_cost = 0
    # path = state_path(bssf)
    # for i in range(len(path)):
    #     this_cost = cost(path[i], path[(i + 1) % len(path)]) 
    #     print(f"Cost between {path[i]._index} and {path[(i + 1) % len(path)]._index}: {this_cost}")
    #     total_cost += this_cost
    # print(f"Total cost: {total_cost}")
    # assert total_cost != float('inf')

    return bssf


def test_strat_bb():
    loc = [QPointF(0, 0), QPointF(1, 1), QPointF(2, 2), QPointF(3, 3), QPointF(4, 4), QPointF(5, 5), QPointF(6, 6),
           QPointF(7, 7)]
    s = Scenario(loc, "Test", 0)
    dist = [[float('inf'), 2, float('inf'), float('inf'), float('inf'), 1, float('inf'), 1],
            [2, float('inf'), 1, float('inf'), 1, float('inf'), float('inf'), float('inf')],
            [float('inf'), 1, float('inf'), 1, float('inf'), float('inf'), float('inf'), 5],
            [float('inf'), float('inf'), 1, float('inf'), 2, float('inf'), 1, float('inf')],
            [float('inf'), 1, float('inf'), 2, float('inf'), 1, float('inf'), float('inf')],
            [1, float('inf'), float('inf'), float('inf'), 1, float('inf'), 2, float('inf')],
            [float('inf'), float('inf'), float('inf'), 1, float('inf'), 2, float('inf'), 1],
            [1, float('inf'), 5, float('inf'), float('inf'), float('inf'), 1, float('inf')]]
    s.setup_test(dist)
    inst = Instrumenter()

    final_state = strat_bb(s.getCities(), 6000, inst)
    # print("Path: ", end="")
    # for p in path:
    #     print(f"{p._index}", end=", ")
    # print(f"queue: {inst.max_queue}; created: {inst.states_created}; pruned: {inst.states_pruned}")

    assert [i._index for i in state_path(final_state)] == [0, 5, 4, 1, 2, 3, 6, 7]


def test_strat_bb2():
    loc = [QPointF(0, 0), QPointF(1, 1), QPointF(2, 2), QPointF(3, 3), QPointF(4, 4), QPointF(5, 5), QPointF(6, 6),
           QPointF(7, 7)]
    s = Scenario(loc, "Test", 0)
    dist = [[float('inf'), 1, float('inf'), float('inf'), float('inf'), 2, float('inf'), 1],
            [2, float('inf'), 1, float('inf'), 1, float('inf'), float('inf'), float('inf')],
            [float('inf'), 1, float('inf'), 1, float('inf'), float('inf'), float('inf'), 5],
            [float('inf'), float('inf'), 1, float('inf'), 2, float('inf'), 1, float('inf')],
            [float('inf'), 1, float('inf'), 2, float('inf'), 1, float('inf'), float('inf')],
            [1, float('inf'), float('inf'), float('inf'), 1, float('inf'), 2, float('inf')],
            [float('inf'), float('inf'), float('inf'), 1, float('inf'), 2, float('inf'), 1],
            [1, float('inf'), 5, float('inf'), float('inf'), float('inf'), 1, float('inf')]]
    s.setup_test(dist)
    inst = Instrumenter()

    final_state = strat_bb(s.getCities(), 6000, inst)
    # print("Path: ", end="")
    # for p in path:
    #     print(f"{p._index}", end=", ")
    # print(f"queue: {inst.max_queue}; created: {inst.states_created}; pruned: {inst.states_pruned}")
    assert [i._index for i in state_path(final_state)] == [0, 7, 6, 3, 2, 1, 4, 5]


# bb_init_state :: [City] -> BbState
def bb_init_state(cities, start_city):
    # Set up cost matrix
    cost_matrix = [[cost(i, j) for j in cities] for i in cities]
    (cost_matrix, lower_bound) = reduce_cost(cost_matrix)

    path = [start_city]

    return (cost_matrix, lower_bound, 0, path)


# gen_next_states :: BbState -> [City] -> [BbState]
def gen_next_states(start_state, pool):
    next_states = []

    source_city = start_state[3][-1]

    for c in pool:
        if not c in start_state[3]:
            new_matrix = copy.deepcopy(start_state[0])
            cost = new_matrix[source_city._index][c._index]

            # inf out row/col the picked path is on
            for i in range(len(new_matrix)):
                new_matrix[i][c._index] = float('inf')
                new_matrix[source_city._index][i] = float('inf')

            # inf out back edges
            for i in start_state[3]:
                new_matrix[c._index][i._index] = float('inf')

            (new_matrix, new_lb) = reduce_cost(new_matrix)
            new_state = (new_matrix, start_state[1] + new_lb + cost, start_state[2] + 1, start_state[3] + [c])

            next_states.append(new_state)

    return next_states


def test_gen_next_states():
    loc = [QPointF(0, 2), QPointF(2, 3), QPointF(3, 1), QPointF(1, -2), QPointF(-2, 0)]
    s = Scenario(loc, "", 0)
    cs = s.getCities()
    cs.sort(key=lambda i: i._index)

    st = bb_init_state(cs, cs[0])

    # ([[inf, 0,    926,  1110, 592],
    #   [0,   inf,  0,    2086, 2763],
    #   [926, 0,    inf,  592,  2863],
    #   [518, 1494, 0,    inf,  0],
    #   [0,   2171, 2271, 0,    inf]],
    #  13923, [])
    assert st[1] == 13923

    nss = gen_next_states(st, cs)
    assert len(nss) == 4

    # 1 -> 2
    (mtx1, cst1, dpth1, pth1) = nss[0]
    assert dpth1 == 1
    assert cst1 == 13923 + 592
    assert pth1 == [cs[0], cs[1]]
    assert mtx1[0][1] == float('inf')
    assert mtx1[0][2] == float('inf')
    assert mtx1[0][3] == float('inf')
    assert mtx1[0][4] == float('inf')
    assert mtx1[0][1] == float('inf')
    assert mtx1[2][1] == float('inf')
    assert mtx1[3][1] == float('inf')
    assert mtx1[4][1] == float('inf')
    # also check back-edge
    assert mtx1[1][0] == float('inf')

    # 1 -> 3
    (mtx2, cst2, dpth2, pth2) = nss[1]
    assert dpth2 == 1
    assert cst2 == 13923 + 926
    assert pth2 == [cs[0], cs[2]]
    assert mtx2[0][1] == float('inf')
    assert mtx2[0][2] == float('inf')
    assert mtx2[0][3] == float('inf')
    assert mtx2[0][4] == float('inf')
    assert mtx2[0][2] == float('inf')
    assert mtx2[1][2] == float('inf')
    assert mtx2[2][2] == float('inf')
    assert mtx2[3][2] == float('inf')
    assert mtx2[4][2] == float('inf')
    # also check back-edge
    assert mtx2[2][0] == float('inf')

    # Now take a step; 1->3 gets used
    nss = gen_next_states(nss[1], cs)
    assert len(nss) == 3
    (mtx3, cst3, dpth3, pth3) = nss[0]
    assert dpth3 == 2
    assert pth3 == [cs[0], cs[2], cs[1]]
    assert cst3 == (13923 + 926) + 2086
    assert mtx3[2][0] == float('inf')
    assert mtx3[1][0] == float('inf')
    assert mtx3[1][2] == float('inf')

    # We'll assume 2->4 is OK
    nss = gen_next_states(nss[0], cs)
    assert len(nss) == 2

    # The final state transition
    nss = gen_next_states(nss[0], cs)
    assert len(nss) == 1
    (mtx4, cst4, dpth4, pth4) = nss[0]
    assert cst4 == (13923 + 926) + 2086 + 0
    assert dpth4 == 4
    assert pth4 == [cs[0], cs[2], cs[1], cs[3], cs[4]]

    for r in mtx4:
        for c in r:
            assert c == float('inf')


def print_matrix(mtx):
    print()
    for r in mtx:
        print(r)


def pprint_state(st):
    # print("/--------------------------------------------------\\")
    print(f"Depth: {state_depth(st)}; lb: {state_lb(st)}", end=" ")
    print("Path: ", end="")
    for c in state_path(st):
        print(f"{c._index}", end=", ")

    # print_matrix(st[0])
    # print("\\--------------------------------------------------/")
    print()


def state_lb(state):
    return state[1]


def state_depth(state):
    return state[2]


def state_path(s):
    return s[3]


def heap_state_lb(state):
    return (state_lb(state), state)


# heap_socre_state :: BbState -> Nat -> Real -> Real
def heap_score_state(state, count_cities, bssf_score):
    # Here is how we score a state:
    # A state that is closer to the bottom of the tree is more
    # valuable than a state higher up in the tree, thus, we reward
    # states where their depth is closer to the number of cities.
    # Furthermore, we treat the "best search so far" value as a sort
    # of *expected cost*. If this function returns a negative value,
    # then that means, roughly, that we're exceeing what the current
    # best search has found.

    (_, lb, depth, _) = state
    return lb - (bssf_score * ((depth ** 2) / (count_cities ** 2)))


def heap_state_depth(state):
    return (state_depth(state), state)


# reduce_cost :: [[Real]] -> ([[Real]], Real)
def reduce_cost(m):
    m = copy.deepcopy(m)
    c = len(m)

    cost = 0

    # Reduce rows first
    for i in range(c):
        mm = float('inf')
        for j in range(c):
            mm = min(mm, m[i][j])

        if mm < float('inf') and mm > 0:
            cost = cost + mm
            for j in range(c):
                m[i][j] = m[i][j] - mm

    # Columns now
    for i in range(c):
        mm = float('inf')
        for j in range(c):
            mm = min(mm, m[j][i])

        if mm < float('inf') and mm > 0:
            cost = cost + mm
            for j in range(c):
                m[j][i] = m[j][i] - mm

    return (m, cost)


def test_reduce_cost():
    inf = float('inf')
    mtx = [[inf, 7, 3, 12],
           [3, inf, 6, 14],
           [5, 8, inf, 6],
           [9, 3, 5, inf]]

    mtx_verify = [[inf, 7, 3, 12],
                  [3, inf, 6, 14],
                  [5, 8, inf, 6],
                  [9, 3, 5, inf]]

    assert mtx == mtx_verify

    (mtx2, cst) = reduce_cost(mtx)

    assert cst == 15
    del mtx2[0][0]
    del mtx2[1][1]
    del mtx2[2][2]
    del mtx2[3][3]
    assert mtx2[0] == [4, 0, 8]
    assert mtx2[1] == [0, 3, 10]
    assert mtx2[2] == [0, 3, 0]
    assert mtx2[3] == [6, 0, 2]

    # Ensure that mtx does not get modified
    del mtx[0][0]
    del mtx[1][1]
    del mtx[2][2]
    del mtx[3][3]
    del mtx_verify[0][0]
    del mtx_verify[1][1]
    del mtx_verify[2][2]
    del mtx_verify[3][3]
    assert mtx == mtx_verify


# still_timep :: Time -> Real -> Bool
def still_timep(start, amount):
    return time.time() - start < amount


# cost :: City -> City -> Real
def cost(c1, c2):
    if c1 == c2:
        return float('inf')
    return c1.costTo(c2)
