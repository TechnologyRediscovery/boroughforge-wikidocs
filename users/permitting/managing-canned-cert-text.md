---
title: Managing canned text on certificates
description: Guide to configuring and applying canned text on certificates
published: true
date: 2026-02-20T15:12:22.237Z
tags: 
editor: markdown
dateCreated: 2026-02-20T15:09:11.060Z
---

# Managing canned text on certificates

CNF provides tools to insert saved chunks of text into certificates either by default during the certificate flow or on a per-certificate basis. These chunks of text are called canned text blocks or canned comments.

The high level steps for configuring canned text blocks on certificates are:
1. Configure the canned text blocks outside of the certificate flow
2. Apply 1 or more canned text blocks to a particular certificate and optionally choose to always attach the selected text blocks to certificates of that type in the future.
 
## Managing canned text blocks
To configure text blocks for use on a certificate: 
1. Navigate to any permit file through a property profile. The easiest path is to use a permit file on your muni property. Your muni property is the property loaded when you enter a new CNF session. You can also access you muni property by clicking the muni tools link in the Municipality box in the upper left of the screen and clicking "muni property" 
2. On the property profile page, permit files live inside units which are listed in the upper right column of the property profile. Click the view permit file link inside any permit file.
![viewpermitfile.png](/permitting/viewpermitfile.png)
3. Once on the permit file profile, locate the panel called Occupancy Certificates in the left column. 
4. Click the link: manage canned comments in the upper right of this panel.
![managecannedcomments.png](/permitting/managecannedcomments.png)
5. This link will display the canne text block manager dialog where you can create a new canned text block, edit existing ones, or deactivating a block. 
6. When creating and editing a canned text block, the drop down called Category is used to select which of the three possible certificate labels your text block can be added to. The three labels you can choose from are Stipulations, Notices, and Comments. All labels function the same way and which you assign your text block to is user preference.
![choosingcerttextheader.png](/permitting/choosingcerttextheader.png)
7. Save your changes to the text block and close teh dialog with the X in the upper right. 
8. Now when configuring a certificate in the flow, you can apply your canned text block to the label as you desire in step 4 using the blue link: choose (label name).
![applyingblocks.png](/permitting/applyingblocks.png)