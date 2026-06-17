---
title: Letters
description: Also called notice of violation
published: true
date: 2026-01-05T14:07:16.848Z
tags: 
editor: markdown
dateCreated: 2026-01-05T13:59:07.398Z
---

# Letters
Letters are template-based documents that can optionally detail 1 or more code violations attached to a CE Case. As of January 2026, letters can only be attached to CE cases. By mid-2026, letters will be cross-purpose on both the occupancy side and the CE side.

## Generic officer signatures
A municipality can opt to sign letters (NOVs) from a generic/arbitrary Person without a signature image. The issuing officer will be tracked internally, and the recipient will only see the designated person as the letters signing party.

The letter configuration dialog displays both the issuing officer and, optionally, the signature of the generic person signer. 

### Setting up generic signing person
These setup steps are undertaken by a system administrator
1. Create a person whose name, title, phone, and email are as desired for the generic signature. Linked mailing addresses are NOT used in letter signatures. This person should now be your session person and displayed in the top session person box.
2. Navigate to the municipality management page and load the desired municipality. 
3. Scroll down to the panel called "User mappings"
4. Click "Inject session person as default". You'll then see you generic person which is loaded into your session mapped to this municipality. When a letter is generated in this municipality, this generic signing person will by default be selected as the signing person
![noneinjected.png](/cecases/noneinjected.png)
![genericloaded.png](/cecases/genericloaded.png)

### Using the generic signing person
Once the generic person is configured, all letters in this municipality will by default be sent by the default person. Officers can click "Change signature block" in the letter configuration to sign the letter by a non-generic person.

![letterwithgenericsigner.png](/cecases/letterwithgenericsigner.png)