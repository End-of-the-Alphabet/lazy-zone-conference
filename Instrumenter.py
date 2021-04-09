class Instrumenter:
    def __init__(self):
        self.max_queue = 0
        self.states_created = 0
        self.states_pruned = 0
        self.solutions_found = 0

    def update_queue(self, new_size):
        self.max_queue = max(self.max_queue, new_size)

    def inc_states_created(self, more=1):
        self.states_created += more

    def inc_states_pruned(self, more=1):
        self.states_pruned += more

    def inc_solutions_found(self, more=1):
        self.solutions_found += more
