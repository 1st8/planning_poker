import VotingTimer from "./VotingTimer.svelte";
/**
 * Builds a liveview hook that mounts the given svelte component using mapped props
 */
const svelteHook = (Component, { mapProps }) => ({
  mounted() {
    this.component = new Component({
      target: this.el,
      props: mapProps.reduce((props, attribute) => {
        props[attribute] = this.el.getAttribute(attribute);
        return props;
      }, {}),
    });
  },
  beforeUpdate() {
    this.destroyed();
  },
  updated() {
    this.mounted();
  },
  destroyed() {
    this.component?.$destroy();
  },
});

export default {
  VotingTimer: svelteHook(VotingTimer, { mapProps: ["startedAt"] }),
};
