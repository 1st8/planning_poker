import Sortable from 'sortablejs';

let SortableIssues = {
  mounted() {
    this.initSortables();
    this.setupObserver();
  },

  initSortables() {
    const element = this.el;
    const isDraggable = element.dataset.draggable !== 'false';

    // Clean up existing sortables
    if (this.sortables) {
      this.sortables.forEach(sortable => sortable.destroy());
    }

    // Find all sortable lists within the container
    const sortableLists = element.querySelectorAll('.sortable-list');

    // Initialize Sortable for each list
    this.sortables = [];

    sortableLists.forEach(list => {
      const columnId = list.dataset.columnId;

      const sortable = new Sortable(list, {
        group: 'issues', // Shared group allows dragging between lists
        animation: 150,
        disabled: !isDraggable,
        dragClass: "sortable-drag",
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        onEnd: (evt) => {
          const issueId = evt.item.dataset.id;
          const fromList = evt.from.dataset.columnId;
          const toList = evt.to.dataset.columnId;
          const newIndex = evt.newIndex;

          this.pushEvent("issue_moved", {
            issue_id: issueId,
            from: fromList,
            to: toList,
            new_index: newIndex
          });
        }
      });

      this.sortables.push(sortable);
    });
  },

  setupObserver() {
    // Watch for changes to the data-draggable attribute
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'data-draggable') {
          const isDraggable = this.el.dataset.draggable !== 'false';
          // Update the disabled state of all sortables
          if (this.sortables) {
            this.sortables.forEach(sortable => {
              sortable.option('disabled', !isDraggable);
            });
          }
        }
      });
    });

    this.observer.observe(this.el, {
      attributes: true,
      attributeFilter: ['data-draggable']
    });
  },

  updated() {
    // Re-check draggable state on LiveView updates
    const isDraggable = this.el.dataset.draggable !== 'false';
    if (this.sortables) {
      this.sortables.forEach(sortable => {
        sortable.option('disabled', !isDraggable);
      });
    }
  },

  destroyed() {
    // Clean up observer
    if (this.observer) {
      this.observer.disconnect();
    }
    // Clean up all sortable instances
    if (this.sortables) {
      this.sortables.forEach(sortable => sortable.destroy());
    }
  }
};

export default SortableIssues;
