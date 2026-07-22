---
title: CodeNforce release notes
description: Major and minor
published: true
date: 2025-12-21T02:39:44.807Z
tags: 
editor: markdown
dateCreated: 2025-12-21T02:39:41.137Z
---

# Release notes archive

Releases prior to the current one. For the latest release, see [Release notes](/system/releases/releasenotes).

## Release 4.8.7 on 29-MAY-2026

- **LSA6-Z** Photo size on notices now respects initial size setting
- **LSA6-Z** Event add dialog no longer bleeds over the bottom of the page
- **LSA6-N** A whole bunch of property data synchronization back end code that isn't ready for production yet

## Release 4.8.6 on 13-MAY-2026

- **LSA6-I** Adding events just got cooler! You can now do an all-type event category search, and even save your own quick event list specific to your user for easy selection during event add time.
- **LSA6-B** Event calendar just got a major facelift: users now have user-specific view controls accessed through the link obscurely named "settings" to choose which events to view in your calendar. Event categories can now be flagged with Date/Time critical, for actually scheduled events: this flag shows up when adding an event in the event add dialog. You can adjust your calendar to only view backlogged follow up events and calendar critical events. These filters now also percolate through to the conventional calendar view.
- **LSA6-B** A new 'bump' feature has been added to follow up events on the dashboard calendar backlog allowing users to kick the follow up event into the future so you don't lose it and you can still clear your back log
- **LSA6-B** When closing a case, the system will automatically deactivate follow up events not satisfied and future events. You can now also view deactivated events on the event lists in property, case, and permit file pages, along with reactivation
- **LSA6-Z2** Citation violation status updates can now be back dated such that marking a cited violation as compliance through adjudication shows up in the proper monthly report! Who knew citation-violation tracking could get so exciting?

## Release 4.8.5 on 11-MAY-2026

- **LSA6-L** Inspected spaces in field inspections can now have custom ordering and sensible default ordering: first by floor, starting with upper floors proceeding to basement, negative floors. User can enter edit space order mode and move spaces up or down manually.
- **LSA7-H** Violation migration from an inspection on CE case that case's violation list now is prompted and configurable on inspection finalization directly in the CE case! NO more migration settings and ugly migration confirmation dialog. Setup violation parameters directly in the finalization box.
- **LSA7-Z** Fixed case close dialog form oddities: reversion back to "compliance" closure event category, fixed bug of all closing events having text about closing due to compliance, added pathway for user to enter custom closing event details at closure time.
- **LSA6-A** Added much more robust caseload refreshing, so you shouldn't have to manually refresh caseload on common case actions that impact the priority bins, like citing a violation, or adding a letter
- **LSA6-F** Improved divergent owner mailing vs. property address searching to return fewer false positive divergences. System will now make smart guesses that 609 E 13TH AVE and 609 13TH AVE are effectively the same address. The chance of the omitted directional being accidental is extremely high.
- **LSA6-Z** Permit files and property profile pages now have a tools panel with a forced refresh and page reload link for stubborn non-updating object issues. Use this link if the page details aren't reflecting actions you just took in a dialog box

## Release 4.8.4 on 7-MAY-2026

- **LSA7-Z** Fixed doubled up citation and violation panels after citation add
- **LSA7-Z** Fixed unable to route CEAR after property assignment
- **LSA7-Z** Attempted to fix wrong caseload loaded after session re-initialization

## Release 4.8.3 on 5-MAY-2026

- **LSA7-Z** Fixed unpredictable search failure on public CEAR search form
- **LSA7-Z** Restored legacy NOV template manager link; it is back from vacation

## Release 4.8.2 on 2-MAY-2026

- **LSA7-M** Added batch parcel log management on property manager
- **LSA7-Z** Fixed parcel ID dash stripping always activating. Now property search by parcel ID honors the state of the "remove dashes" checkbox
- **LSA7-MN** Upgraded Westmoreland county parcel data harmonization process for incoming Trafford
- **LSA7-L** Properties now all have been assigned a county designation
- **LSA7-A** Letter upgrade WIP: letters can now live directly on properties and inside permit files, and of course still on CE Cases; Letters are fully "mail mergable" with custom fields.
- **LSA6-G** Action requests: citizens who call in a complaint and internal user enters their email now get a confirmation email.
- **LSA6-G** Action requests: Added resident type: neighbor; Extended confirmation message on internal form without photo attachments.
- **LSA6-N** Municipalities can now designate official contacts for various system purposes, such as inter-officer communication via act 90, public contacts, manager contacts, etc. Accessed via session muni box in upper left; muni tools; muni contact manager

## Release 4.7.2 on 17-APR-2026

- **LSA6-G** Code enforcement action requests have been completely upgraded! Now Action Requests have their own management page, complete with dashboard counts, easy viewing of requests in the right-hand detail column, and advanced search features as used to exist on the dashboard.
- **LSA6-G** An internal action request submission form now makes municipal staff submission of requests much easier on a custom, single-page form featuring a new "muni general" request such as "please sweep all of gas line way for trash violations" or "please bring Ellen Bascomb copies of all recent permits to the muni office on Thursday"
- **LSA6-G** Custom action request reports now feature month-over month time series data showing the trends in action request reporting.
- **LSA6-Z** When creating a new permit file, the selected manager "sticks" when choosing a manager who is not the current user

## Release 4.6.0 on 26-MAR-2026

- **LSA6-A** Caseload manager now features a batch case close feature which allows officers to not only batch close cases ready for closure but also mark violations compliant on non-cited cases and then conduct the closure!
- **LSA6-A** Users can now view, print, and mark as mailed letters directly from the caseload manager cards
- **LSA6-A** Users can jump to case cards from the administrative todo listings in the caseload manager
- **LSA6-A** Administrative flags on cases can be suppressed using a command link under the admin flags on a case's profile.

## Release 4.5.3 on 15-MAR-2026

- **LSA6-W-2** Allow back dating of letter lock, sent, and returned dates
- **LSA6-A** Scroll panel in lightning config

## Release 4.5.2 on 11-MAR-2026

- **LSA6-Z-3** Made session flushing more robust to squash wrong muni's cases appearing in case search on dash
- **LSA6-J** Lightning cases can now automatically link multiple violations with canned findings injected automatically, editable before lightning case creation. The new lightning dialog will also allow Letter recipient choice, and auto-dropping into the case profile of the freshly made lightning case! Give it a whirl.
- **LSA6-W-1** Person connections now show their family classifications, with case connections a glaring orange, and the others more pastel colored.

## Release 4.5.1 on 6-MAR-2026

- **LSA5-C** BETA launch of new caseload manager on dashboard; still needs auto-refresh on case actions
- **LSA5-Z** Fixed cannot see citation controls on view citation link click
- **LSA5-C** Relaxed close blockers for no terminal citation status log
- **LSA5-C** Relaxed close blockers for no violation on case
- **LSA5-Z** Fixed Lou cannot see himself in the caseload manager drop down list

## Release 4.4.2 on ?-MAR-2026

- **LSA5-A** Case manager with batching and easy list access and management

## Release 4.4.1 on 2-MAR-2026

- **LSA6-C** A muni-wide text block manager provides easy viewing, editing, and linking of canned findings, certificate text details, and more; Access this from your muni session box -> muni tools -> text block manager
- **LSA6-C** Code book ordinance enforcement parameters can now be updated in a batch via ordinances -> code book
- **LSA5-Z** Disappearing NOV on finalize and lock bug fixed
- **LSA6-C** Ord categories can now be edited directly in the code source manager

## Release 4.4.0 on 25-FEB-2026

- **LSA5-A** Case status is now fully upgraded to include ready for closure alerts, administrative cleanup flags, auto closure reminders, and more.

## Release 4.3.2 on ?-JAN-2026

- **LSA5-W-3** Dashboard calendar is now filterable by user and calendar events can now be viewed in a conventional, pannable calendar view accessed with "explore full calendar" link at the top of Event Calendar panel
- **LSA5-H** Owner occupant person links on a property will now also get slurped up as the property's owner
- **LSA5-W-7** Permit file managers can now be changed and auto logged with a descriptive event.

## Release 4.3.1 on 26-JAN-2026

- **LSA5-F** Property evaluations now have a few new tweaks: You can now clone across munis easily from the evaluation builder; photos now print on the reports; and westmoreland county towns can now submit blight records to the mother ship at the Redevelopment Authority automatically!
- **LSA5-B** New permits now label authorized use "Permitted use" and not "Proposed use" going forward. Already issued or drafted permits will still read "Proposed use"
- **LSA5-P** Property alerts are now easy! Just use the "add property alert" action link on the property profile and choose your alert type.
- **LSA5-P** You can now also search for properties by active alert at a given point in time using the "Properties by active alert" pre-built query.
- **LSA5-F** Property evaluation upgrades: photos now print on the eval report; cloning can now be undertaken across municipalities; bugs in editor squashed; reorder now works with top/bottom jump links; deac blueprint works now.

## Release 4.3.0 on 31-DEC-2025

- **LSA5-G** Municipalities can now sign letters with a generic signature to anonymize the issuing officer. Contact system admin to setup this person. Officer extensions now print on NOVs--just make sure your user's person has an extension registered. Find your user person with the new person tools link in the session person box.
- **LSA5-G** Adding follow-up events when recording NOV mailing is now optional!
- **LSA5-O** When conducting inspections, compliance and inspection stamps should match inspection date/time, not now()
- **LSA5-S** Property search by county parcel ID now doesn't always strip dashes; added boolean toggle on search params
- **LSA5-Z** Random checklist chosen if muni defaults aren't setup to avoid erroring out inspection add page
- **LSA5-Z** Added note that muni header images must have a title to be selected in the muni
- **LSA5-Z** Added warning note requiring default severity when adding ords to codebook by system admins
- **LSA5-L** No longer display the ugly warning on Addresses with building number zero. Enforce more address rules. Fixed address form
- **Westmc** Fixed major parsing issue with westmoreland county harmonization

## Release 4.2.1 on 22-DEC-2025

- **LSA-5** Westmoreland county data assimilation for beta testing: prop addresses, owner name, and tax mailing
- **LSA-Z** Fixed loading all properties on property profile page load; added parcellog reviewing UI

## Release 4.2.0 on 22-DEC-2025

- **LSA-5** Westmoreland county data assimilation for beta testing: prop addresses, owner name, and tax mailing

## Release 4.1.1 on 18-DEC-2025

- **LSA4-Z** Fixed muni profile unable to add new bug
- **LSA4-Y** Allow manager event cat manage

## Release 4.1.0 on 2-DEC-2025

- **LSA4-U** Persons linked to a unit now display in the unit/period/certs/fins table in upper right of prop profile
- **LSA5-Z-1** Inconsistent success of person merges has been fixed and person search re-runs after merge to reflect deactivated sub person
- **LSA5-Z-10,23,30** Permit dialog and citation dialog should no longer be cut off on the bottom

## Release 4.0 on 16-NOV-2025

- **LSA4** You can now add all properties in a search result to a group in one go, allowing for convenient grouping of properties that match search criteria.
- **WestMC-B** Property evaluations are now buildable! These are non-ordinance based assessments with basic survey-like functionality.
- **LSA4-S** Special property search now in beta testing to list properties whose owner mailing address is different from the property address. Test it out: property search and groups then query drop down to "Property address different from owner mailing" and expand advanced search and tinker with the match threshold.

## Release 3.6.5.2 on 17-OCT-2025 (collapsed with 3.6.4)

- **LSA4-Z:** Fixed 504 on case docket report
- **LSA4-Z:** Including "HEARING_SCHEDULED" citation violation status.
- **LSA4-Z-12:** Removing a photo link to an inspection item no longer deletes that photo from the entire system. Yikes! Sorry about that, folks.
- **LSA4-Q:** Citation search includes a half dozen new search filters and results can now be routed to a printable citation report page with summary statistics!
- **LSA4-R:** FIN follow up events are now based on the parent container: CE case follow up events are different from permit files and you can opt out of auto followup event on failed inspection finalization
- **LSA4-Z-18:** Rich text now displays properly on field inspection flags

## Release 3.6.3 on 12-SEP-2025

- **LSA4-W:** Spacing in occ inspection photos; removed violation photos header

## Release 3.6.2 on 8-SEP-2025

- **LSA4-W:** Occ inspection report tweaks: full-width comments section; two-wide photo printing; sensible page breaks
- **LSA4-W:** Nullified permits can now still be viewed for printing with an ugly banner declaring it null and void.
- **LSA4-P:** Certificate sort order now is finalized first, then un-finalized.

## Release 3.6.1 on 4-SEP-2025

- **LSA4-Z:** With Permit file bug fix
- **LSA4-O:** Added advanced query tools for occ permits, including a beta test of a filtering mechanism for expiring permits which are followed by a non-expiring permit
- **LSA4-P:** Permits (certs) now have a status and show their expiry date and window on the permit file cert list.
- **LSA4-P:** Permits (certs) now have a status and show their expiry date and window on the permit file cert list.

## Release 3.5.20 on 3-SEP-2025

- **LSA4-Z-14:** Violation add cancel not actually canceling
- **LSA4-Z-11:** CEAR routing controls should now work consistently, and view CEAR link (red text with number of CEARs) now works from any page, not just dashboard
- **LSA4-B:** Violations can now be unnullified by a case's manager, or muni manager or better users!
- **LSA4-N:** Inspection comments can now be saved for future use in your or other municipalities!
- **LSA4-Z:** Inspection reports no longer print headers for "Pre-inspection notes" and "Comments" if none are entered by the officer.

## Release 3.5.19 on 14-AUG-2025

- **MAP-B1:** Activated URL-encoded pre-filling of muni on CEAR form.

## Release 3.5.18 on 18-JUL-2025

- **LSA3-Z:** Fixed again removal of "photo attachments" header when there are zero attachments.

## Release 3.5.17 on 8-JUL-2025

- **LSA3-Z:** Fixed mis-printing the section character on NOV photos and don't print "photo attachments" when there are zero attachments.

## Release 3.5.16 on 25-JUN-2025

- **LSA3-I:** Field inspection dates should now properly be auto-populated in the certificate creation flow.
- **LSA3-B:** You can now sort the inspection violation tables by category, ordinance, or inspection outcome without losing your entered data!
- **LSA3-C:** Notice of violations now can contain the photos associated with any or all associated violations, with custom sizing available on the NOV configuration
- **LSA3-G:** Emergency contact flagging: a person can be flagged as an emergency contact and individual phone numbers can also be flagged
- **LSA3-Z-3:** Property and person search results are automatically limited to 150 to avoid overloading DB; users can change or disable result limiting in advanced search
- **LSA3-L:** Muni profile edits now work
- **LSA3-Q:** Letter management bug fixes: letter type changes now propagate without a session reload, current muni filter default on types
- **LSA3-E:** UMAP sortable list for system admins

## Release 3.5.15 on 9-JUN-2025

- **LSA3-Z:** Fix address sorting bug.
- **LSA3-H:** Tree-based ordinance browser single select bug has been fixed on Field Inspection browsing.
- **LSA3-U2:** Property list reports can now be generated via the property search list box.

## Release 3.5.13 on 5-JUN-2025

- **LSA3-H:** Tree-based ordinance browser has been resurrected on cecase violation add and inspections.
- **LSA3-Z:** Citation penalty and violation level penalties have been adjusted to hopefully fix 810,000 converting to 810 on entry

## Release 3.5.12 on 21-May-2025

- **LSA3-V:** Alpha prototype of the import machine.
- **LSA3-B:** Units now have a "common area flag" that will eventually have workflow requirements attached.

## Release 3.5.10-11 on 4-May-2025

- **LSA3-Z:** Partial fix of failure to properly load person profiles incident to citation act 90 flagging upgrade.
- **LSA3-Z:** Act 90 flags now show on property owner display
- **LSA3-S:** Property groups now display on inspection routing and dashboard prop search results
- **LSA3-Z:** Fixed unable to create case on property without a mailing address link

## Release 3.5.8 and 9 on 23-APR-2025

- **LSA3-K** Persons linked to a citation or docket are given a yellow alert box under their name in search, profile, and when configuring permits that says "Review for act 90". Persons linked to a citation with a guilty outcome are shaded dark purple in the person profile.
- **LSA3-Z:** Printing property photo on case report is now optional and defaults to false
- **LSA3-Z:** County property data links no longer bleed into property info.
- **LSA3-Z:** Auto navigate to destination case when attaching CEAR to existing case
- **LSA3-Z:** Inspection destination property and unit now appear as expected when rerouting from one case/permit file to another
- **LSA3-Z:** Inspection flags were broken and are now fixed

## Release 3.5.7 on 16-APR-2025

- **LSA3-Z** Default to table view on inspection ord browsing and known bug notice.

## Release 3.5.6 on 19-MAR-2025

- **LSA3-Z** Enforceability info edit now doesn't crash out the dialog.

## Release 3.5.4 on 5-MAR-2025

- **LSA3-N** When adding ordinances into a codebook, ordinances can be filtered by searching header text, full text, and by presence in the target codebook! Also, duplicate ordinances will not be added to a target codebook.
- **LSA3-Z** Checklist clone now works as expected

## Release 3.5.3 on 28-FEB-2025

- **LSA2-M** Added "counts as compliance" flag on citation violation and adjusted reporting to reflect compliance during court. You can now also search for violations by citation-violation status (such as dismissed, withdrawn, etc.)

## Release 3.5.2 on 25-FEB-2025

- **LSA2-F** Field inspections can now include alert flags that display prominently in the inspection dialog, and on field inspection reports. They can be customized by town to say anything the user desires.
- **LSA2-Z** Fixed error: Unable to see newly added unit and added auditing to now allow duplicate unit or empty unit numbers
- **LSA2-W** Add permit file type to unit/occ period grid display on property profile

## Release 3.5.1 on 10-FEB-2025

- **LSA2-Z** Fixed error: no violations injecting into lightning cases
- **LSA2-Z** Fixed error: Broken side bar menu links
- **LSA2-Z** Fixed error: Navigate to permit file from event calendar on dash broken
- **LSA2-Z4** Space/room attributes (size, floor, location) are now duplicated on reinspections by default and can be disabled.

## Release 3.5.0 on 7-FEB-2025

- **LSA2-C** Properties can now be grouped into custom-named bundles such as property developments, demolition candidates, etc. Groups are accessed and managed on the standard property search dialog and on the property profile page directly.
- **LSA2-I** Citation penalties and fees are now aggregated across all citations on a given case for display on the bottom of the citation panel, on the case docket report, and on the cecase list report, when enabled (which it is by default).

## Release 3.4.0 on 22-JAN-2025

- **LSA2-L** Interserver communication REST endpoint on Wildfly activated
- **LSA2-L** Implemented caching for field inspections and cache dumping when uploading from Handheld Tool.
- **LSA2-L** Auto case cache dumping every morning at 0100h using CDI injected beans!
- **LSA2-k** Search for citation on officer-assigned citation number
- **LSA2-G** All dashboard searches now "stick" even after leaving dashboard and returning to dash
- **LSA2-J** Permit files can now be searched by event activity, defaulting to 30 days in past

## Release 3.3.2 on 9-JAN-2025

- **LSA2-Z** Fixed bug on broken inspection screen on permitfiles on properties without any cecase
- **LSA2-F** Findings on inspection items and code enforcement case violations can now be saved and used again later. Users can store an unlimited number of stored findings and manage them without leaving the inspection or violation add dialogs.
- **LSA2-B** Field inspection can now be routed to another muni if attached in the wrong town by mistake: Use the Transfer and Deactivation panel in the lower left corner of the inspection details dialog.
- **LSA2-Z** Auto generated followup events on letter sending has been reactivated.

## Release 3.2.3 on 13-DEC-2024

- **LSA2-B** Field inspections can now be routed to any other muni for which a user has officer permissions (and to any active muni for system admins)

## Release 3.2.2 on 11-DEC-2024

- **LSA2 15-2-Z** Fixed bug: broken building display view on address picker
- **LSA2 15-2-Z** Added selection checkboxes back to violation select and a half dozen other tables

## Release 3.2.1 on 2-DEC-2024

- **Hillman 15-2-L:** Code enforcement case list reports now include breakdown of action requests!
- **Hillman 15-2-L:** Occupancy activity report now includes a clearer breakdown of field inspections by outcome
- **Hillman 15-2-E:** Added Not cited-terminal citation violation status

## Release 3.2.0 on 25-NOV-2024

- **Hillman E:** CE Case reopening operation
- **Hillman D:** Enlarged findings boxes on field inspection flows with toggle for collapsed sizing!
- **Hillman D:** PrimeFaces 14 upgrade; bug squashes: duplicate issuing code source on certs; invisible rich text buttons bug fixed; routed Enter key presses to next buttons on permit flow

## Release 3.1.2 on 20-NOV-2024

- **Hillman D:** Fixed broken inspection checklist manager page
- **Hillman D:** Citation status management working now
- **Hillman D:** Certificate types can now be added without proposed uses, and those left empty shall not print on permit

## Release 3.1.0 on 16-NOV-2024

- **Hillman 15-2-D:** Case ID numbers no longer appear on Letters
- **Hillman 15-2-E:** Violations now have a pretty color coded status and when a violation is cited, then all updates to the violation happen through the citation and its log entries and citation-violation status updates
- **Hillman 15-2-E:** Citations and citation violations now can hold penalties of various kinds such as officer requested, district court imposed, and imposed on appeal

## Release 3.0.9 on 27-SEP-2024

- **Hillman 15-D:** Fixed broken occupancy activity report and violation search
- **Hillman 15-D:** Adjusted batch violation UI language
- **Hillman 15-D:** Tweaked violation findings logic to remove single paragraph extra spacing
- **Hillman 15-D:** Field inspection reports now display correct unit association when accessed from property home page
- **Hillman 15-D:** Fixed bug: deac on person mailing address links not propagating to certificate even with person refresh link click
- **Hillman 15-D:** Removed failed audit facility completely!
- **Hillman 15-D:** Fixed property manager link role no auto-populating on property page

## Release 3.0.8 on 20-SEP-2024

- **Hillman 15-2-A:** Field inspection search results now contain working links to the parent property and ce case/permit file
- **Hillman 15-2-G:** Umap log tracking query re-enabled
- **Hillman 15-2-B:** Added inspected space ord display in the details edit dialog for easy transfer to fields
- **Hillman 15-Z-9:** Users can now apply batch code violation actions: extend stip comp dates, compliance, and nullification
- **Hillman 15-2-D:** System admins can now add to checklists from any codebook

## Release 3.0.7 on 4-SEP-2024

- **Hillman 14-M:** Inspected spaces now can contain notes, dimensions, and occupancy limits on reports

## Release 3.0.6 on 2-SEP-2024

- **Hillman 14-Z:** Backup ordinance text view links added to inspection and violation add UIs for testing.

## Release 3.0.5 on 30-AUG-2024

- **Hillman 14-M:** Unit person links now eligible for printing on inspection reports
- **Hillman 14-Z:** Attempted fix for unable to add selected ords from source
- **Hillman 14-M:** Draft of more advanced inspected space details: no reporting yet

## Release 3.0.4 on 22-AUG-2024

- **Hillman 14-M:** Clone facility now available for inspection checklist spaces; copying now available also
- **Hillman 14-M:** Rich text editing on inspection findings

## Release 3.0.3 on 19-AUG-2024

- **Hillman 14-O:** Clone facility now available for entire code sources!
- **Hillman 14-Z:** No inter-muni lock out on person merging for muni staff or better

## Release 3.0.2 on 13-AUG-2024

- **Hillman 14-Z:** Fixed bug on CE case Field Inspection report setup screen crashing

## Release 3.0.1 on 6-AUG-2024

- **Hillman 14-Z:** Handheld inspection session display now refreshes properly on muni switch.
- **Hillman 14-Z:** CompareTo contract breach locations surrounded with try/catch
- **Hillman 14-Z:** Session object and view objects are now officially all cleared on muni switch
- **Hillman 14-H:** Inspection dispatch caching disabled due to stale inspections after dispatch and upload.

## Release 3.0.0 on 1-AUG-2024

- **Hillman 14-H:** Database caching subsystem operational with system admin control panel offering enable/disable/flush for each of 9 caching managers
- **Hillman 14-Z:** Edits on NOVs are now "sticking" as expected.
- **Hillman 14-Z:** Certificate/permit header image and width now pull from the muni settings directly, not via the default print style. Now the default print style only is used for letters whose type doesn't have a declared print style.

## Release 3.0.0 (1-AUG-2024, second entry)

- **Hillman 14-H:** Database caching subsystem operational with system admin control panel offering enable/disable/flush for each of 9 caching managers
- **Hillman 14-Z:** Edits on NOVs are now "sticking" as expected.

## Release 2.3.15 23-JULY-2024

- **Hillman 14-Z:** Fixed 504 page bug on public CEAR form

## Release 2.3.14 19-JULY-2024

- **Hillman 14-Z:** Adjusted inspected space dialog to use scroll bars for overflow

## Release 2.3.13 17-JULY-2024

- **Hillman 14-Z:** Parcel deac now works as expected and directs users to dash after completion
- **Hillman 14-Z:** Case close form now cancels as expected
- **Hillman 14-Z:** System admins can now deac a CE Case completely, including all sub-objects!
- **Hillman 14-L:** Certificates can now have custom person link labels!! System admins can configure custom permit types.
- **Hillman 14-J:** Text blocks can now be stored as default on certificate types

## Release 2.3.12 8-JULY-2024

- **Hillman 14-Z:** Resurrected canned text for permits. Use the "manage canned comments" link in the certificate panel to add and edit canned text.
- **Hillman 14-Z:** Fixed bug on location descriptors (again)

## Release 2.3.11 4-JULY-2024

- **Hillman 14-Z:** Fixed bug on location descriptors that was causing errors in handheld upload syncing
- **Hillman 14:** Added muni profile switch to turn on and off display of muni addresses on permits

## Release 2.3.10 27-JUNE-2024

- **Hillman 14-Z:** Major facelift to location descriptors on inspection spaces: they can be location descriptions and/or floor numbers
- **Hillman 14-Z:** Resolved violation transfer from dispatched FINS to ce cases

## Release 2.3.9 11-JUNE-2024

- **Hillman 14-Z:** Fixed checklist add/edit bug Number 2194

## Release 2.3.8 10-JUNE-2024

- **Hillman 14-D:** Mailing addresses can now be added quickly in the traditional three box form and matching candidates are displayed for review
- **Hillman 14-Z:** Tree based ordinance select on ce cases no longer collapses on each add; Full ordinance text is now also available on the table view filter
- **Hillman 14-B:** Ordinance last updated timestamp is now written on category update on browser triggering handheld checklist cached copies to be dumped for fresh ones

## Release 2.3.7 29-MAY-2024

- **Hillman 14-D:** Mailing address quick add now live for testing: add a new address (building no, street, and ZIP Code) all in one form.

## Release 2.3.6 16-MAY-2024

- **Hillman 14-Z:** Inspection checklist edit now works as expected
- **Hillman 14-D:** Beta big table filter mailing address search now available from the dashboard

## Release 2.3.5 13-MAY-2024

- **Hillman 13-H:** Key muni docs are now uploadable and visible from any screen using the muni session box: click muni tools then choose: important muni files and docs
- **Hillman 14-F:** Lightning cases can now be configured to NOT automatically finalize letters on generation. This is a little check box inside a lightning case's settings.

## Release 2.3.4 10-MAY-2024

- **Hillman 13-B:** Pretty status icons now display for spaces with all passed items or no inspected items
- **Hillman 13-B:** Assigned inspections now appear on case or period display without a reload
- **Hillman 13-B:** Making a new person without a phone or email now won't make empty ones

## Release 2.3.3 9-MAY-2024

- **Hillman 13-B:** A lilac color now denotes dispatched inspections
- **Hillman 13-B:** Photos can be uploaded to finalized inspections (again)
- **Hillman 13-B:** CECase add can now have a default origination event cat
- **Hillman 13-B:** Reinspections are now working as expected
- **Hillman 13-B:** The inspection creation process is now dramatically simplified: default checklists are now selected based on user's parent object (ce case or permit file), default causes are selected, and even frequently used spaces are automatically added to the inspection during creation. Finally, inspections can be dispatched to the handheld software tool at the moment of inspection creation, reducing overall clicks required for creating a base inspection from six to two!
- **Hillman 13-B:** Field inspection interfaces have been upgraded to show ordinance outcomes on the main profile page
- **Hillman 13-B:** Inspection determinations can now include a "Documentation only" setting that is neither pass nor fail

## Release 2.3.1 25-APR-2024

- **Hillman 13-B:** Session object boxes have been optimized; clicking the name of the person, property address, case name, or permit file type replaced the "view" links
- **Hillman 13-Z:** Field inspection ordinance screen blanking bug fixed; ord selection tree doesn't collapse on ord selection; ordinance findings and pass/fail status save on view change
- **Hillman 13-B:** Field initiated inspections from the handheld software tool are now assignable via a slick four-step UI accessible from the dashboard

## Release 2.3.0 17-APR-2024

- **Hillman 13-D:** Final person merging updates implemented: full auto-refreshing after merge, and a confirm dialog
- **Hillman 13-D:** Person search has been upgraded to allow for searching by phone, email, merge status, date, user, and alias searching occurs by default alongside primary name searching.
- **Hillman 13-B:** Upgrade to field initiated inspection UI with dashboard notices of inspections that need routing and those dispatched

## Release 2.2.10 9-MAR-2024

- **Hillman 13-D:** Persons can now be merged into one another with the guts of one person being migrated to the guts of the primary person
- **Hillman 13-Z:** Fixed aliases not appearing on person profiles after alias creation

## Release 2.2.9 28-MAR-2024

- **Hillman 13-Z:** Bug on certificate drafting fixed; this was related to parcel info objects not getting auto-generated properly during parent property configuration
- **Hillman 13-D:** Persons can now have aliases AND can be linked to other persons in the system, so a person can be listed as the owner of an LLC, for example
- **Hillman 12-I:** On tree view, ordinances with failed sort first on re-view of that table; sort cols had to be removed because they erased ordinance data

## Release 2.2.8 12-MAR-2024

- **Hillman 12-I:** Inspection tree ordinance add now allows add of both failed and pass, and tree "next" routes to same screen as table view: severity and migrate to case
- **Hillman 12-L:** Person-CECase "nov recipient" links aren't duplicated on sending a second NOV to the same person
- **Hillman 12-C:** Permit amendments are ready for user testing: finalized permits can be amended within a 45 day window
- **Hillman 12-Z:** Added logic to prevent dead address link dialog from null on Audit trail prep
- **Hillman 12-Z:** Removed address link role auto filter on parcel ID search
- **Hillman 12-Z:** Fixed wrong dates displaying on human link dialog

## Release 2.2.7 8-MAR-2024

- **Hillman 12-Z:** Fixed broken NOV type add/edit and missing Accounting event type
- **Hillman 12-C:** Test pathway for the certificate amendment process -- feedback please
- **Hillman 12-Z:** Property mailing address update now does not close on click of "edit"
- **Hillman 12-A:** Tweaks from user feedback on permitting flow: show full contact on person step; allow hiding of duplicate email, phone, and addresses

## Release 2.2.6 1-MAR-2024

- **Hillman 12-G:** Fixed broken muni header upload tool and broke up muni manage page
- **Hillman 12-Z:** Fixed NOV recipient mailing addresses not displaying the previewed address
- **Hillman 12-A:** Certificate person add dialog no longer closes on validation errors, but rather displays an error message

## Release 2.2.5 24-FEB-2024

- **Hillman 12-Z:** Fixed broken occupancy reporting (incident to removing times from permit dates)
- **Hillman 12-A:** Permit file type display on dashboard listing

## Release 2.2.4 22-FEB-2024

- **Hillman 12-A:** Testable permit flow with saved dynamic fields, easy person linking, and step-based navigation.

## Release 2.2.3 16-FEB-2024

- **Hillman 12-A:** More functional test of new certificate flow
- **Hillman Z:** Attempted bug fix on permit person address links NOT loading

## Release 2.2.2 22-JAN-2024

- **Hillman 12-Z:** Property profile permit file display is now mega slick, with inspections and certificates listed with ZERO additional clicks

## Release 2.2.1 22-JAN-2024

- **Hillman 12-K:** Ordinance headers are now editable during update of individual ordinances
- **Hillman 12-z:** Fixed CE case profile info broken update form
- **Hillman 12-z:** Fixed CECase info not updatable
- **Hillman 12-A:** Save permit draft values inside the new permit flow!

## Release 2.2.0: 7-JAN-2024

- **Hillman 11-F (Events):** CNF now automatically deploys events (when configured in muni profile settings) when permits are issued--including expiring permit reminders, when NOVs are marked as sent, field inspections are finalized--and when failed field inspections require follow up, as well as when citation log entries are made that relate to specific calendar dates such as filing and hearings. These substantial features have incremented our minor release number from 1 to 2!!
- **Hillman 11-F (Events):** Events displayed system wide, including from searching and reporting, now reflect an event category's view rank floor! This setting can be configured during report config for ce case list and case docket reports allowing users to set the view floor at their rank or lower.
- **Hillman 11-F (Events):** The event add dialog now features a revised layout more consistent with our two-column style system wide. This new sporty style boasts an upgraded event category list box which provides category level detail regarding follow-up and property-alert characteristics. Users can also view category level detail on their selected category using an aptly named link at the top of the right column.
- **Hillman 11-F** Users can now add a general event to the muni calendar which will display as **GENERAL EVENT**
- **Hillman 11-C** You can now edit the raw HTML on ordinances, allowing for inclusion of spiffy tables and super fancy formatting inside a code element's technical text.
- **Hillman 11-E** The reinspection button now lives inside an overlay panel, preventing accidental clicks

## Release 2.1.9: 3-JAN-2024

- **Bug fix** on permit finalization.
- **Hillman f:** Stable property events and follow-up events, but alerts are still WIP

## Release 2.1.8: 2-JAN-2024

- **Bug Fix:** Template edits "not sticking" bug fixed. Now template edits are actually working!

## Release 2.1.7: 28-DEC-2023

- **Hill11-F:** Property alert events are now active and can be configured by system admins to any muni's heart's desire
- **Hill11-F:** Event end times auto-correct when before an event start time
- **Hill11-F:** Event lists auto sort to reverse chrono order
- **Hill11-F:** Event descriptions now support rich text, like bullets, enter presses, bold face, underlining, etc.
- **Hill11-F:** Event Configure screen now has sensible columns with pretty formatting

## Release 2.1.6: 28-DEC-2023

- **Hill11-F:** Follow-up events now have special yellow flags prompting user to log another event to satisfy the follow-up requirement
- **Hill11-G:** Routing of field-initiated fins now works with slick highlighting of options
- **Hill11-G:** Code elements now have a customizable header that sticks with that ordinance forever
- **Hill11-G:** Code guide now has rich text editing and creator/update tracking
- **Lightning cases** can now have a display order, and help offered on ordinances

## Release 2.1.4: 12-DEC-2023

- **Bug Fix** Inspection report config dead page
- **Hill11-F** Event subsystem facelift initial parts

## Release 2.1.3: 5-DEC-2023

- **Hill11-A** Property units now can have their own mailing addresses!!
- **Bug fix:** Auto select current user on permit init
- **Bug fix:** Null user person on NOV finalize

## Release 2.1.2: 4-DEC-2023

- **Hill-10: I:** Clear property list on session init

## Release 2.1.1: 3-DEC-2023

- **Hill-10: Tweaks** to include dashboard property search and owner/manager phones and emails on profile
- **Hill-10:M - Muni profile switch on default address search link role filter**
- **Hill-10:M - Dashboard now features simplified property search!**

## Release 2.0.8: 30-NOV-2023

- **Hill-10: Property page** revamp first pass: property info is right at the top, units and periods are collapsed
- **Hill-10: Lightning case draft**

## Release 2.0.7: 9-NOV-2023

- **Fixed bug on ord tree** generation assignment
- **Fixed remove ord from violated list** on CECases when adding from the tree
- **Auto refresh muni-codebook mappings** on the code book management page

## Release 2.0.6: 9-NOV-2023

- **Ordinance and code book refresh** bug squashed to show real-time updates on code books and ords
- **Property and unit info on inspections** added to dialog header in inspection profile, inspection entry dialog, and pass/fail confirmation dialog

## Release 2.0.5: 9-NOV-2023

- **Fixed save findings bug** on inspection tree view: clicking "add ordinance" to violated list will save notes and severity on already violated ordinances
- **Wrap text and view ord** added on inspected item tree for field inspection add

## Release 2.0.4: 7-NOV-2023

- **hillman10-N:** Browse ordinances in a tree form on inspections and cecases!
- **Feature:** When adding new ordinances, users can build a new ordinance based on a clone of the chapter, sec, sub sec, and sub sub sec number and titles; Also, edited and added ords get added to the top of the ord list for easy user confirmation
- **hillman10-Z:** Fixed inspection comments not "sticking"

## Release 2.0.3: 31-OCT-2023

- **hillman10-J:** Auto-select issuing code sources when creating a permit
- **hillman10-Bug:** Fixed auto-reload of issued permits

## Release 2.0.2: 27-OCT-2023

- **Hill-10-D:** Occupancy permitting and inspection detail hybrid report is now available for immediate generation from a start to stop date of your choosing; Default switches show maximum information. Turning off sections with a simple click makes customization a breeze.
- **Ordinance chapter and section:** on inspection form are cleaned up

## Release 2.0.1: 25-OCT-2023

- **Hill-10-L:** In-depth info on citation display
- **Hill-10: Bugs** Fixed reinspection button bug

## Release 2.0.0: 19-OCT-2023

- **Field inspection** load time adjusted to only load full checklist on inspection view
- **Caching** layer implemented in CodeIntegrator, PersonIntegrator, MuniIntegrator, UserIntegrator
- **Event calendar** now only displays 5 events in a list, hiding the rest in an accordion that is, by default, closed at 6+ events
- **Events** now loaded with property info directly on base class event; eliminated PropertyUnitPeriodDataHeavy subclass entirely!

## Release 1.7.3: 4-OCT-2023

- **Letter templates** are now simplified and no longer require selecting a cryptic entry in a drop-down box each time you want to choose a template.

## Release 1.7.2: 27-SEP-2023

- **Occ period status** now is accounting for failed inspection re-inspection windows.
- **Known issues:** 1) Excessive permit file load times still exist and are actively being trimmed. 2) Occasional session init and page load errors (which are incident to the persistent and unidentified database connection "leak")

## Release 1.7.1: 26-SEP-2023

- **Hillman 9: Occ period status** now is displayed when viewing occ periods in the dash search, property profile page, and the period itself
- **Property search is now mobile friendlier**
- **Field inspection search now works from the dashboard** which allows querying all non-finalized inspection for muni-wide tracking purposes
- **Draft task manager** is live for the system admins to begin configuring. Occ period level tasking coming soon.

## Release 1.6.18: 21-Aug-2023

- **BITS 14:** Audit trail on mailing addresses and code ordinance and header fields
- **Bug fixes:** Resurrected date of record on field inspections

## Release 1.6.17: 7-Aug-2023

- **Hillman 8-I:** Field inspection determinations, inspection causes, and all intensity ratings are now municipality specific and are configured by system admins through the page called "manage drop-down lists"
- **Hillman 8-F:** Linked object roles now have priority for sorting

## Release 1.6.16: 31-July-2023

- **Hillman 8-D: Property search sort:** Results on the property search now are sorted by building number then street name, with reverse link. AND parcel ID searches now automatically remove '-' characters from inputs
- **Hillman 8-E Event time sort:** Events now sort in reverse chronological time from most recent to least recent
- **Hillman 8-H Canned text blocks:** Occ permits now allow users to create and use canned stipulations, notices, and comments, along with custom comments.

## Release 1.6.15: 31-July-2023

- **BITS task 10: calendar export of events** now exists on the dashboard, CE Case, Occ period, and Property pages! Custom list selection dumps into a file digestible by Outlook Apple calendar, and Google Calendar!!
- **BITS task 11: Ordinance filter now available on selection of violations,** in the ordinance add and codebook manage pages!!
- **H8-G: Inspection deactivation** now operates as expected
- **BITS task 13: Audit trail on person fields** now gets written to the notes field
- **BITS task 12: Session choice table** is now simplified; Extra info now in the row expansion

## Release 1.6.14: 19-July-2023

- **Field inspection UI has been tweaked** to easily allow navigation to either space-level dialog and a help notice for uploading photos to individual items. Photos now have their own panel that shows all uploaded files without an additional click to "view photos".
- **Reinspections can now be initiated directly from the inspection list** on cases and permit files
- **Sorted bug relating to photo/doc lists on cases** actually showing photos and docs on the most recently viewed field inspection
- **Adjusted CECase and permit file query on session init** to not force abort the entire session build on query exception

## Release 1.6.13: 13-July-2023

- **Field inspection from Dash** works all the way through now, along with correct address on reports initiated from the dash

## Release 1.6.12: 12-July-2023

- **The inspection interface has now been updated and appears much more stable than before.** Photos and severity ratings are inputted in a much more organized dialog following the initial space input screen. Remember: upload photos to the entire inspection first, then allocate them to individual ordinance.

## Release 1.6.11: 11-July-2023

- **Work in process (inspection interface is flaky until next patch ETA end of business Tuesday): Overhaul of inspection photo upload system:** Users now upload to the inspection pool only and match element photos from that inspection pool
- **Fixed Broken unit number update**

## Release 1.6.10: 11-July-2023

- **Ticket 1797: Show un-finalized inspections** on inspection config dialog for easy finalization
- **Ticket 1798: Display property address** on inspection info dialog
- **Ticket 1799: Empty findings** are no longer wrapped in meta data during reinspection
- **Auto-linking of persons receiving an NOV to parent CECase**
- **Ticket 1792: Broken removal of inspection finalization** is now fixed--remove away
- **Ticket 1800: Inspection finalization status moved to top of left column** of inspection profile dialog for easy user review

## Release 1.6.9: 6-July-2023

- **H7-E: Muni profile switches for auto-loading of CECases and Permit Files** with default for case load: true, default for occ periods: false
- **H7-L: Upstream person pools are now live** so when you go to add persons to a case, for example, the lower left box of the person search dialog shows the parent property's person links. Similarly, when linking persons on a citation, the parent case persons are the user's candidates. Current functionality does not "hop" a parent's link pool, meaning when linking a person to a citation, users are only shown the citation's direct parent pool: the CE Case, not the case's containing property. Users must add person links down each generation of the tree manually.

## Release 1.6.8: 5-July-2023

- **Inspection init from dash** is available for both permit files and ce cases, without an additional click on "actions"
- **H7-F: Search logs on dash are gone.** Poof!
- **H7-H: Properties will now all have a unit PRIMARY.**
- **Property units can now be deactivated** if they do not have a permit file inside their bellies
- **H7-I: Duplicate phone types are gone**
- **H7-J: Active filter on property search is now in an advanced search box**
- **H7-k: Event search advanced tools** are now inside a special expandable panel

## Release 1.6.7: 26-June-2023

- **Pesky event list on cecase dashboard list refresh fixed**
- **Parcel-attached events now show up on calendar!**
- **CE Case "view case" link** on special session box accessible case list now works
- **Inspections can now start on the dashboard** for ce cases and permit files using the "actions" link in the "Action" column

## Release 1.6.6: 20-June-2023

- **H7-D: Event add from dash on CE case now displays correct type list**
- **Ticket 1734: Broken permit file view link**

## Release 1.6.5: 19-June-2023

- **Cross-muni read-only status has been verified** and xmuni logging implemented in DB
- **CEAR help links** inserted in panel headers

## Release 1.6.4: 13-June-2023

- **Cross-muni links on persons now display the external muni's name** in the light salmon colored cross muni view row
- **Resurrected auto-load of open case list on session init** and added case list link in session ce case box

## Release 1.6.3: 12-June-2023

- **H6-D: Cross-muni viewing facility in place which allows viewing of cecase and parent properties when citation and dockets are linked to persons**
- **BITS-8: Field inspection dialog** sequence streamline and mobile responsiveness

## Release 1.6.2: 6-June-2023

- **Fixed CEAR no property selection bug**
- **Person links now include rich descriptions** like property addresses and event cats, and not just object IDs

## Release 1.6.1: 5-June-2023

- **H6-G: Fixed inconsistency in case closed counts** by street on the CE Case List Report and to boot ya'll got a switch on your case list report config that turns on a listing of all objects that compose the master counts on the summary section of the report. Try it out!
- **H6-H: Case deactivation re-enabled** for sys admins or your own cases (which were created relatively recently)
- **H6-C: CEAR final tweaks:** Fixed broken back buttons; added internal note appending feature for both public and internal notes

## Release 1.6.0: 1-June-2023

- **H6-C: CEAR Routing and Searching** is now functional, completing the beta for CEAR submission by public and internal users
- **BITS Task 7: Icon management** tool now exists for system admins, along with a slick icon picker

## Release 1.5.4: 25-May-2023

- **Upgrade to PrimeFaces 12!**
- **H5-L: Upgraded ordinance display logic; ordinance page now contains preview of all ordinance headers under the display table**
- **H6-C: Code Enf action requests internal routing works for existing case attachment only**

## Release 1.5.3: 19-MAY-2023

- **BITS task 6: Multi object management interface is now live!**
- **H6-C: Code Enforcement action requests:** Simplified public-facing photo upload. Back end can now view CARS but cannot manage them yet. CEAR auto searches on session build, and the CEAR panel is live under CE Case Search

## Release 1.5.2: 16-MAY-2023

- **BITS: Task 5:Linked object role management page now exists**
- **H6-C: Code Enforcement action requests** have been partially resurrected: public facing forms are available for review, but batch photo upload still crashes due to DB leak.
- **H5-L: Ordinance display cleanup** to deal with empty () is WIP: ordinances show their header display along with header generation logic in the ordinance manager which will aid in additional debugging.

## Release 1.5.1: 4MAY2023 1000h

- **BITS: CO1-T28:** Dashboard, session bar, and side bar are now supposed to be optimized for tablet and handheld computer screens
- **H5-J: Addresses upgrade:** Mailing addresses can now contain secondary unit designators, attentions, and PO Box support!
- **H5-G: Citation adds auto-update** violation status
- **H5-I: Alpha sort event types and cats**
- **H5-P: Typo on case docket report fixed**
- **H5-D: Leak Hunt continued:** muni objects on BlobLight objects and NOVType objects have been flattened to muniNameFlattened and muniCodeFlattened and UI adjusted to accommodate
- **H5-O: Turned off permit file search items** that are inactive; renamed occ period to permit file
- **H5-N: Case list pie charts shrunk** down to 300px wide
- **H5-M: Clone Checklist** is now available as a utility accessible from a link called 'clone checklist' at the top of the checklist detail (right column) of the checklist manager page.

## Release 1.5.0: 20-APR-2023 2300h

- **Unit numbers appear on FIRs** but only for non-PRIMARY units
- **BITS 1348: Ord filter** Add an ordinance filter to the inspection page; inspection page cleanup
- **Map tool link on Dashboard with** custom header images for each muni. Map tool link in final debugging

## Release 1.4.9: 20-APR-2023

- **Code sources refactored** during database leak hunt! May the Java gods smile kindly on our endeavor.
- **System admins can now view session authentication logs** under the System sub-menu on the left side-bar--filterable by date range to boot!

## Release 1.4.8: 17-APR-2023

- **Deactivated space types** in field inspection checklists now still show up in completed inspected spaces, along with deactivated space elements.
- **Evens on properties** now should appear with consistency.

## Release 1.4.7: 14-APR-2023

- **Session authentications** are now logged; records contain the date, time, user-muni-auth-period, IP address, session ID, and some basic browser data like vendor and version and patch status. Retrieval is by back end only.

## Release 1.4.6: 11-APR-2023

- **Person links and all their goodies** can now be selected for display on a field inspection!
- **Odd permit printing page redirect error** was investigated and not solved; users can "re-view" the permit file of the offending permit and the printing page loads correctly. A custom error page was made with these instructions for the user and more extensive debugging directives added to back end for further investigation.

## Release 1.4.5: 4-April-2023

- **NOV template editor** is back to rich text, and single Enter press note added to template manager and NOV editor
- **Current user now default** inspector and field inspections don't default to edit mode after checklist select is complete
- Ticket 1575 closed: **Letter type deactivation** works now

## Release 1.4.4: 30-March 2023

- Benchmark deliverable 001: **Court Entity management** page is now live and available for system admins.

## Release 1.4.3: 28-March 2023

- H4: Item I: **Remove media injection into rich text editors** on code elements and NOVs, etc.
- Ticket 1557: **Occ permits are draftable by any user with edit permissions** and up (Beyond requiring muni staff rank no additional permit drafting restrictions are possible. Permit finalize/issue can still be restricted to CEOs or managers.)
- Actually fixed session object synchronization

## Release 1.4.2: 27-March 2023

- Hillman 4-Q: Ordinance entry form now **only requires a chapter title.** Some ordinance title formatting issues remain outstanding due to complex database change.
- **Property search results get wiped** on session re-init, reducing confusing cross-muni output
- Ticket 1557: **Citation drafting** and other operations now conform to muni profile specification
- **User lists are now muni-specific** when selecting user managers for CE Cases, permit files, permits, and citations
- **Session object synchronization is now much more stable:** selecting to view a property, cecase, or occ period will now change the other two objects to the first instance associated with your chosen object. If chosen object has no linked sub-objects (cecases and occ periods if viewing a property), no session object is loaded.
- Hillman 3-C: **Search by street name** issue has been fixed
- Permissions for **system admins** tightened down per the specs
- Events can be edited and deactivated by the event's creator OR the cecase or permit file manager

## Release 1.4.1: 23-March 2023

- MuniProfile and UMAP-based **permissions checkpoints** are now enforced in all relevant subsystems. Study the contents of the new **permissions** link to the session info dialog in the municipality session box. View your current UMAP rank and CEO status along with your muni profile settings. Report all bugs to the master bug tracker via Natalie at the TCVCOG 412.858.5115
- Permit file list on property profile page **now includes unit numbers**
- Server time zone is now **GMT-5**
- Total unit counts **are no longer displayed on field reports**
- NOV mailed and follow-up events **now appear automatically on the cecase's event list on NOV mailing**
- Red notice text and disabled text edit boxes **prevent users from editing a letter's text before choosing a notice recipient**

## Release 1.4.0: 9 March 2023 @ 1630h

- Allowed file types for upload now include **.ods, .odt (open document text and spreadsheets), .docx, .doc, .xls, .xlsx, .txt, csv**

## Release 1.3.9: 2 March 2023 @ 1021h

- **CE Case docket reports** no longer reference property info case status, since PICs have been vaporized
- **Event IDs no longer displayed** above event table
- **Permit file/occ period authorization** tool hidden; locked start/end still active

## Release 1.3.8: 1 March 2023 @ 0845h

- **Units can be added to a mailing address** but this feature is not fully implemented due to complexity of interaction with property units and the optional nature of a unit association
- **Session property box restored** to initial state purged of any mention of a parcel ID
- **NOV editing works** as expected (again, hopefully)
- **Broken searches removed** on property, person, and cecase searches
- **NOV events for mailing and follow-up** work again, as expected

## Release 1.3.7: 28 Februray 2023 @ 0904h

- **CECases no longer auto-search** on session init
- **Property info cases are gone** which were an old organ for storing events which may have been gumming up case search. Person info cases are also toast, which were never fully implemented.
- **Property-person links now update** the session bar and the person panel as expected
- **Permit files now have working person links** accessible on the permit file home page
- **Citations and Dockets also now have working person links** accessible in the citation and docket dialogs respectively
- **Events now have working person links** accessible from the event profile.

## Release 1.3.6: Friday, 24 Februray 2023 @ 1150h

- **CE Case Create** bug has been squashed
- **NOV Edit** bug has been squashed and NOV formatting is much prettier

## Release 1.3.5: Wednesday, 22 Februray 2023 @ 1003h

- **Checklist space types and ords** can now be deactivated even if used in an inspection!

## Release 1.3.4: Tuesday, 21 Februray 2023 @ 23:45h

- **Cases can now be deactivated** by system admins
- **Parcels can now be deactivated** by system admins
- **Code Sources are insertable and have been launched** from primitive to our most current UMAP-based permissions system structure
- **Address link priority now updates** correctly

## Release 1.3.3: Friday, 17-FEB-2023

- **Event search by type and category** on the dashboard now works as expected
- **Code book builder's** load ordinances button refreshes list immediately on press

## Release 1.3.2: Sunday 12-FEB-2023 @ 2145h

- **Property address link notes** now update automatically
- **Property address link cancel works** as expected
- **Person link record source** now actually updates
- **Be on the lookout for** your current person when editing; make sure it is your intended person if navigating to person info from a person link

## Release 1.3.1: Thursday, 9-FEB-2023 @ 2330h

- **Letter types update automatically** on initial drop down menu selection

## Release 1.3.0: Thursday, 9-FEB-2023 @ 1630h

- The default unit name is now **PRIMARY**
- **Deactivation of permit files** is now active
- **MuniManage page** is alive
- **Address roles no longer print** on occ permits
- **Occ Permits now print on town letterheads**
- **Overall photos** are default on field inspection reports
- **When finalizing field inspections,** a confirm dialog now pops up after determination selection
- **Person and address links have been debugged,** to allow for deactivation, and notes, and no dead boxes
- **New event categories** default to "active" on creation

## Release 1.2.1: Thursday, 2-FEB-2023 @ 0500h

- **Muni profile** page is now operational for system administrators to add, edit, and remove municipalities, muni permissions profiles, and print styles

## Release 1.1.2: Thursday, 12-JAN-2023 @ 12:00h

- **Punch-list fixes:** Removing governing code source on checklists; Brought checklist page into modern interface: selected checklist has highlighted "selected" text; added View All Munis and View Inactive on checklist object table
- **Photos/Documents (Blobs) are now attachable to permit files (occ periods)**
- **Events are working on permit files**
- **Inspection ordinance form no longer updates with AJAX on every click**

## Release 1.1.1: Sunday, 8-JAN-2023 @ ~10:40h

- **Patched error in loading CodeSource objects** which was incident to a partially implemented test of cross-muni functionality.

## Release 1.1.0: Saturday, 7-JAN-2023 @ 13:45h

- **Back-end change to street name field from name to stname** during debugging WPRDC scrape mess!

## Release 1.0.12: Friday, 6-JAN-2023 @ ????h

- **Implement initial phases of the permissions work for Glassport onboarding** which involves a single on/off code officer flag on UMAPs, and the removal of developer permissions.
- **Person linking to a property unit is now functional** from the person info page's right-most column.

## Release 1.0.11: Thursday, 5-JAN-2023 @ ????h

- **Letter types and template manager updated** to auto-update on category creation and category help box added. This resolves ticket no. 1424
- **Violations can now be migrated to just opened cases** which resolves ticket no. 1423
- Search by parcel ID now includes **tip to remove dashes**
- Person links to parcels **now allows user to jump directly to that parcel from person info dialog.**

## Release 1.0.10: Wednesday, 4-JAN-2023 @ 1440h

- **Ordinance category lists are not sorted** in the drop-down menu in category management
- **CECase report loads** successfully

## Release 1.0.9.1: Thursday, 20-DEC-2022 @ 0815

- **Embedded links to help articles** in panel headers across the land.

## Release 1.0.9: Thursday, 8-DEC-2022 @ 0945h

- **User-Muni-Auth-Periods now contain a code officer yes/no** attribute set at time of UMAP creation

## Release 1.0.8: Thursday, 1-DEC-2022 @ 0945h

- **Fixed broken CE Case list report** (Duplicate rendered attribute--spillover from table mess)

## Release 1.0.7: Tuesday, 22-NOV-2022 @ 1300h

- **Fixed broken side bar-sub nav item's pseudo action method to extractPagePath()** and tested
- **Addressed ticket #1359: unable to see all users on userconfig.xhtml:** This was not a bug, but rather logic intended to limit sys admin's access to other muni's users; this restriction has been removed and now all users are visible to any sys admin or greater credentialed user
- **Fixed bug in ticket #1360:** UMAP creation no longer has dead screens
- **Fixed bug in ticket #1361:** Umap deactivation now works as expected with flags and auto coloration of records
- **Fixed bug in ticket #1362:** Password can now be reset by system admins, and forced to be changed by user on next login
- **Total Overhaul of User Management System**
- **UMAP add and deac work as expected, along with code officer oath utilities**
- **Logging on all user changes** now allows for full tracking of a user's history
- **User configuration parameters are now displayed** on the session init screen, along with deactivated UMAPs
- **Passwords resets by users can now be forced by system admins.** Users must complete a reset form before initiating an internal session

## Release 1.0.6: Tuesday, 15-NOV-2022 @ 0346h

- **Squashed bug #1406:** letter template table not rendering (culprit: missing var attribute)
- **Squashed bug #1413:** Load addresses not working (culprit: table filtering!)
- **Squashed bug #1415:** Ordinances are now visible on checklist builder (culprit: table filtering!)
- **Addressed ticket #1408:** Turned person linking back to not collapsed
- **Addressed ticket #1407:** This has been addressed in bug squash #1413
- **Squashed bug #1346: The event calendar** on the dash updates itself each time users change their muni, not just on session init
- **Addressed ticket #1404:** Side bar icons have been resurrected
- **Code Book management page has links instead of empty buttons**

## Release 1.0.5: Sunday, 13-NOV-2022 @ 12320h

- **Bug #1400: Fixed:** erratic behavior on person search results table
- **Person linking panels now appear collapsed in the person search dialog**

## Release 1.0.4: Thursday, 10-NOV-2022 @ 0754hh

- **Fixed error on checklist manager page load** and all 174 other data tables to prevent loading a null list object.

## Release 1.0.3: Wednesday, 2-NOV-2022 @ 23:50h

- **Permit file start dates will now default to the current date** (and not a month from the current date as in prior releases).

## Release 1.0.2: Wednesday, 2-NOV-2022 @ 23:50h

- **Debugged empty table page load error on person links; watch like a hawk for similar page crashes.**

## Release 1.0.1: Monday, 31-OCT-2022 @ 23:50h

- **Debugged broken inspection dispatch record management**

## Release 1.0.0: Monday, 31-OCT-2022 @ ????h

- **Compiled with Oracle JDK 18!** (from 8)
- **Packaged for Wildfly 26!** (from 14)
- **Packaged with PrimeFaces 11!** (from 10)
- **Jakarta-EE libraries only** (no more Oracle javaxee)!
- **Backed by PostgreSQL 15!** (from 9.8)


