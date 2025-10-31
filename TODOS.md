- Cancelling the editing of section after entering text should restore content of section to state when editing was started (keeping previously saved edits!)

- When a new section is added during editing by adding content with double newlines, the section should then be split again at the newlines, resulting in new sections for everything but the first.

For example editing "My content" to "My content foo\n\nHello World" becomes two sections "My content foo" and "Hello World"

- In lib/planning_poker_web/live/planning_session_live/show.html.heex I want to have a ReadinessControlsComponent for mode == magic_estimation that allows participants to indicate their readiness level regarding the current issue understanding so the moderator knows when to proceed. Add 5 humourous buttons with expressions ranging from "huh?" through "okay I guess" to "10/10 got it". Selecting a button should show the status in a second line below the participants name. This is supposed to be a fun feature.
