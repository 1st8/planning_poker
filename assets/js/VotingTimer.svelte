<script>
  import { beforeUpdate } from "svelte";
  import { parseISO, intervalToDuration, formatDuration } from "date-fns";

  export let startedAt;
  const formatOptions = { format: ["minutes", "seconds"], zero: true };

  let start, end, duration;
  $: start = startedAt ? parseISO(startedAt) : null;
  $: end = start ? new Date() : null;
  $: duration = start && end ? intervalToDuration({ start, end }) : null;

  beforeUpdate(async () => {
    if (start) {
      setTimeout(() => {
        end = new Date();
      }, 1000);
    }
  });
</script>

<div class="text-xs">
  {duration
    ? "Time elapsed: " + formatDuration(duration, formatOptions)
    : "Timer not started"}
</div>
