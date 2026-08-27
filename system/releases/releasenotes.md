---
title: CodeNforce release notes
description: Major and minor
published: true
date: 2025-12-21T02:39:44.807Z
tags: 
editor: markdown
dateCreated: 2025-12-21T02:39:41.137Z
---

# Release notes

## Release 5.4.0 on 27-Aug-2026
- **LSA7-D Letters:** Letters no longer append a note about photo compression at the end of each generated letter.
- **LSA7-R Person links:** A new unified person linking dialog allows easy linking of session person or searched for person to any other session object in a single dialog, no stacked link role selection dialog. 
- **LSA7-R Persons:** A recent persons list is maintained for each user allowing easy viewing of recently loaded person profiles. Clearable with a single click.

## Release 5.3.0 on 26-Aug-2026
- **LSA7-D Letters:** Muni specific templates now enabled.
- **LSA7-D Letters:** Refactored from letter display table to a letter card model similar to CE case cards in the caseload manager


## Release 5.2.0 on 25-Aug-2026

- **LSA7-D Letters:** Fixed address 1 and 2 line injection points not printing. Also added a one line city, state, zip injectable along with issuing office phone/email injection.
- **LSA7-D Letters:** Allow multiple letter parents for each template
- **LSA7-D Letters:** Converted to a dedicated LetterStyle that specifies header image height, not width, and this leaves all legacy NOV/Letters 
- **LSA7-D Letters:** A bunch of bug fixes from Sharpsburg testing: Issuing officer reverting back to current user, display of proper print styles in the letter flow.
- **LSA7-D Letters:** Migration facility allows easy construction of new Letter system template from legacy NOV system.
- **LSA7-Z Property range addresses:** Fixed bug concerning a property's display address improperly reverting to piece of a range. Built in manual override of property mailing address links via the MAD link priority. If any link has a priority 2 or higher, then highest priority displays as property primary address link, regardless of the underlying logic in the Linked Object Role manager.

## Release 5.0.0 and 5.1.0 on 18-Aug-2026
- **LSA7-D Letters overhaul:** Our new letter subsystem includes a JPEG image compression tool! A letter with 8 images taken at full smartphone resolution was reduced from 55.2 MiB to 1.6 MiB! With automatic emailing of letters to recipients, the attached PDF shouldn't blow up any inboxes. AND, since we got compression working for new letters, auto-compression has now been extended to field inspection reports! Images viewed in normal browser view mode (the ugly off-center dialog) are NOT compressed at all--all pixes are sent to the browser for zooming way in. 
- **LSA7-D Field inspection compression:** Field inspection reports now display recompressed jpeg images! No more third party pdf compression tools. This also applies to the new Letters subsystem.
- **LSA7-G Workflow engine pre-release:** The rental registry and related occupancy workflow engine is now live for pre-release feedback and testing.
- **LSA7-G Muni-specific events:** Each muni can now create event categories specific to their municipality, and see those events in a special new event add tab called: muni-specific categories.
- **LSA7-H Permit file case links** Permit files and CE cases can now be formally linked when an occupancy situation becomes a court-mediated process. [See feature documentation here.](/users/permitting/linking-permit-files-to-ce-cases.md). Links made also appear in the CE case profile panel.


## Release 4.8.9 on 24-July-2026

- **LSA7-W-6:** When creating a citation, the person linking dialog now easily allows users to choose the defendant from a list of all property, property-unit, an cecase links. 
- **LSA7-Z:** Fixed broken permitting config page from schema dumping. No more workchain tab on the permitting config page
- **LSA7-Z:** Fixed property page refresh required to view groups and deactivated person links
- **LSA7-Z:** Fixed duplicate NOV addressees on preview after resetting mailing status, and now username and timestamp are saved to NOV notes when mailing is reset
- **LSA7-W-8:** Permit files can now be configured to auto-populate with 1 or more events at creation, such as a fee required follow up event! Contact your friendly neighborhood system admin to configure this feature.

## Release 4.8.8 on 21-July-2026

- **LSA7-W-7: Custom cert numbers** On the last step of certificate generation, users can choose to assign a custom certificate number, which must be unique in the muni. You'll get a finalization error and chance to correct conflicting cert numbers.
- **LSA6-W** Added tools to view which ordinances have static headers, which is critical for handheld app functioning
- **LSA6-Z** Citation-violation status now can be back dated in a batch!
- **LSA6-N** Improved data sync capabilities as part of major data sync build out. Current data sync and exchange subsystem is in alpha development stage.
- **LSA7-Z** Fixed lightning case dialog bleeding off bottom of page

---

Older releases have been moved to the [release notes archive](/system/releases/releasenotes-archive).


