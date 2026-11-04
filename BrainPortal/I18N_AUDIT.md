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

## Confirmed findings and fix PRs

Paths below are relative to BrainPortal. The findings below now have separate fix
PRs targeting `dev`, tested in English and French. These are pending changes,
not a claim that the fixes have already merged or been deployed.

| Area | Source and examples | Verification scope | Fix PRs |
| --- | --- | --- | --- |
| File upload notifications | `app/controllers/userfiles_controller.rb`: `File Uploaded`, `Collection Uploaded`, failed collection upload | Success/failure messages in both locales; preserve API behavior | [#1691](https://github.com/aces/cbrain/pull/1691) |
| Collection merge and archive extraction | Same controller: `Collections Merged`, `File extraction completed/failed` | Success/failure and singular/plural counts; preserve names and links | [#1692](https://github.com/aces/cbrain/pull/1692), [#1693](https://github.com/aces/cbrain/pull/1693) |
| Data-provider repair notifications | `app/controllers/data_providers_controller.rb`: repair progress and failed-repair summary | Zero/one/multiple inconsistencies; stub repair operations | [#1694](https://github.com/aces/cbrain/pull/1694) |
| Viewer and availability responses | `userfiles_controller.rb`: selection/viewer errors; `data_providers_controller.rb` and `bourreaux_controller.rb`: `No Information Available` | HTML/AJAX responses and escaping of filenames/viewer names | [#1696](https://github.com/aces/cbrain/pull/1696) |
| Task submission summary | `app/controllers/tasks_controller.rb`: `Submitted ... tasks; some messages follow.` | One/multiple submissions; keep tool names unchanged | [#1695](https://github.com/aces/cbrain/pull/1695) |
| Project invitations | `app/models/invitation.rb`, `send_out`: invitation subject and email body | Recipient-language policy, in-app display and captured email; no real invitations | [#1697](https://github.com/aces/cbrain/pull/1697) |
| Work-directory notifications | `app/models/cluster_task.rb`: saved/failed work-directory messages | Worker locale loading and recipient language; preserve task links | [#1698](https://github.com/aces/cbrain/pull/1698) |
| Loading feedback | `public/javascripts/cbrain.js`: `Loading...`, `Error loading element` | Success/error AJAX paths; put translated text in HTML per #1660 | [#1699](https://github.com/aces/cbrain/pull/1699) |
| File launch bar | `public/javascripts/userfiles.js` and `cbrain/userfiles/launch_task.js`: `Select some files to launch`, `Launch`, `No files selected` | Empty/selected files, button enablement and launch parameters | [#1700](https://github.com/aces/cbrain/pull/1700) |
| Boutiques preview | `cbrain_plugins/cbrain-plugins-base/cbrain_task/boutiques_task/views/_form_js.html.erb`: unequal cbcsv lengths warning, changing-parameter heading and `Task` column | Single/multiple lists and unequal lengths; keep descriptor values unchanged | [#1701](https://github.com/aces/cbrain/pull/1701) |
| Other built-in tool forms | `simple_file_extractor`, `cb_serializer`, `bash_scriptor` views: headings and explanatory text | One tool per PR; distinguish UI prose from executable examples | [#1702](https://github.com/aces/cbrain/pull/1702) (SimpleFileExtractor), [#1703](https://github.com/aces/cbrain/pull/1703) (CBSerializer), [#1704](https://github.com/aces/cbrain/pull/1704) (BashScriptor) |

## Follow-up validation

The fourteen fixes were composed with the existing i18n changes, including
#1677, in the isolated Apple-container deployment (Ruby 2.7.8 / Rails 5.0.7.2).
English/French checks covered the real notification construction expressions
with 0/1/2 counts, actual invitation callbacks and captured email, and the
worker save method with file/provider operations stubbed. Invitation and worker
messages were checked with the process locale opposite to the recipient's
saved preference; the worker dictionary also loaded independently of the portal.

Browser checks covered persisted notifications, actual tool partials and their
controls/help, viewer/availability responses and escaping, AJAX loading/error
handlers, launch selection/button/payload behavior, and single/multiple/unequal
CBCSV previews. External operations were not run: no emails were delivered,
provider repairs performed, scripts executed, or processing jobs launched.
Each fix PR records its specific test scope and limitations.

The preview checks also exposed a numeric/string CBCSV ID mismatch that hid
multi-list previews and warnings; #1701 fixes that comparison.

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
pass. The invitation and work-directory follow-ups now use the recipient’s saved
language; other background-message paths still need auditing before making a
system-wide recipient-language guarantee. Keep #1660 open for the broader
coverage and dictionary audits described above; the concrete rows in this
inventory are now covered by the linked fix PRs.
