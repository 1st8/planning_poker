import Sortable from 'sortablejs';

let SortableIssues = {
  mounted() {
    const element = this.el;
    
    // Find all sortable lists within the container
    const sortableLists = element.querySelectorAll('.sortable-list');
    
    // Initialize Sortable for each list
    this.sortables = [];
    
    sortableLists.forEach(list => {
      const columnId = list.dataset.columnId;
      
      const sortable = new Sortable(list, {
        group: 'issues', // Shared group allows dragging between lists
        animation: 150,
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
  
  destroyed() {
    // Clean up all sortable instances
    if (this.sortables) {
      this.sortables.forEach(sortable => sortable.destroy());
    }
  }
};

export default SortableIssues;
