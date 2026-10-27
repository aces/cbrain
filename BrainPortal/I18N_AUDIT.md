# CBRAIN interface translation audit

Snapshot: 2026-10-27, for [#1660](https://github.com/aces/cbrain/issues/1660).
This is a source audit and follow-up inventory, not a claim of complete
English/French coverage. NeuroHub and external plugin repositories are excluded.

## Compared changes

The audit uses `dev` at `6c27b2452`, Natacha's #1677 at `0067e3e4`, and
our #1678–#1684 presentation/notification patches. It also accounts for the
separate follow-ups for the Boutiques description toggle, Descriptor Maker
controls/help, Zenodo notifications, and the site-description label cleanup.
These patches were composed in a temporary source snapshot before scanning.
Do not treat a pending PR as already deployed.

## Confirmed remaining strings

Paths below are relative to BrainPortal. Each row is suitable for a separate,
scoped follow-up; it is not covered by the changes above.

| Area | Source and examples | Suggested verification |
| --- | --- | --- |
| File upload notifications | `app/controllers/userfiles_controller.rb`: `File Uploaded`, `Collection Uploaded`, failed collection upload | Success/failure messages in both locales; preserve API behavior |
| Collection merge and archive extraction | Same controller: `Collections Merged`, `File extraction completed/failed` | Success/failure and singular/plural counts; preserve names and links |
| Data-provider repair notifications | `app/controllers/data_providers_controller.rb`: repair progress and failed-repair summary | Zero/one/multiple inconsistencies; stub repair operations |
| Viewer and availability responses | `userfiles_controller.rb`: selection/viewer errors; `data_providers_controller.rb` and `bourreaux_controller.rb`: `No Information Available` | HTML/AJAX responses and escaping of filenames/viewer names |
| Task submission summary | `app/controllers/tasks_controller.rb`: `Submitted ... tasks; some messages follow.` | One/multiple submissions; keep tool names unchanged |
| Project invitations | `app/models/invitation.rb`, `send_out`: invitation subject and email body | Recipient-language policy, in-app display and captured email; no real invitations |
| Work-directory notifications | `app/models/cluster_task.rb`: saved/failed work-directory messages | Worker locale loading and recipient language; preserve task links |
| Loading feedback | `public/javascripts/cbrain.js`: `Loading...`, `Error loading element` | Success/error AJAX paths; put translated text in HTML per #1660 |
| File launch bar | `public/javascripts/userfiles.js` and `cbrain/userfiles/launch_task.js`: `Select some files to launch`, `Launch`, `No files selected` | Empty/selected files, button enablement and launch parameters |
| Boutiques preview | `cbrain_plugins/cbrain-plugins-base/cbrain_task/boutiques_task/views/_form_js.html.erb`: unequal cbcsv lengths warning, changing-parameter heading and `Task` column | Single/multiple lists and unequal lengths; keep descriptor values unchanged |
| Other built-in tool forms | `simple_file_extractor`, `cb_serializer`, `bash_scriptor` views: headings and explanatory text | One tool per PR; distinguish UI prose from executable examples |

## Dictionary cleanup

The site form's duplicate `sites.new.labels.description` entries can be replaced
by the existing `attributes.description` through `f.label :description`; the
separate cleanup patch preserves "Description" in both languages.

General unused-key removal remains open. A missing literal reference does not
prove a key is unused: views use relative keys, helpers construct keys from
states/types, and Rails resolves model attributes implicitly. For each proposed
removal, inspect those consumers and render the relevant form in both locales.
Identical English/French values can be valid (e.g. "Description"), not missing
translations. Keep worker fallback strings and technical identifiers intact.

## Method and limits

Search the composed snapshot with `rg` for `errors.add`, `flash[`, message
`:header`/`:description` arguments, HTML text, and `alert`/`confirm`/loading text
in controllers, models, first-party JavaScript and built-in tool views. Inspect
multiline strings and call sites rather than treating search matches as bugs.
Exclude vendored/minified JavaScript, logs, API identifiers, descriptor-provided
content and NeuroHub from automatic recommendations. API response text needs
separate compatibility review before modification.

The initial candidate scan covered 25 non-NeuroHub controller files, 132 model
files, 3 top-level first-party JavaScript files, and 34 built-in tool view files;
follow-up inspection included the nested file-launch JavaScript. Candidate
matches include SQL, translated fallbacks and markup, so they are not defect
counts. This pass does not cover every portal view/helper, external plugin,
email, worker execution path or dynamically generated string.

After these follow-ups merge, repeat the source scan and a bilingual browser
pass. In particular, verify background-message language explicitly: translating
a string in the current process locale does not establish a recipient-language
policy. Keep #1660 open until these remaining audits and decisions are resolved.
