---
title: Setting up property alert events
description: Configuring the start/stop event category pair behind a property alert banner
published: true
date: 2025-12-17T16:14:25.737Z
tags: subsystem:property, audience:staff, type:reference
editor: markdown
dateCreated: 2025-12-17T16:14:21.477Z
---

# Setting up property alert events

The property event alert displays in an orange banner at the top of the property page.
Property alert events are special events — when added to a property, case, or permit file,
they trigger a flag to appear at the very top of the property profile, warning users of a
condition of importance on the property.

Property alert events can be any event type and category. As of January 2024, a dedicated
event type, "Property Alerts", was created to house alert events.

Users create alert events in pairs (event tools > event setup and categories > new event
category > property alerts):

1. Begin by making a new event category that represents the **end** of the alert. The stop
   alert category is a regular category — this is **not** called an alert event. Do not check
   the "Alert Event" box for a stop category; only check it for a start event.
2. Create the event category that will trigger the property alert to appear. Choose the
   category title carefully, since the title text is the only text displayed on the alert
   flag.
   - When configuring the alert event, check the **Alert Event** box.
   - In the **Alert stop category** field, select the ending alert event category created in
     step 1.
   - Configure the rest of the event category as appropriate (min rank to create, view,
     read-only, update staff, or other choice).
   - Icon hints: use `inspection-pass` for a cleared check mark, `inspection-fail` for an
     exclamation image.
3. To trigger the property alert, add the alert event to the property itself, or to any case
   or permit file living inside that property. When the property profile is viewed, the alert
   appears at the top.

   > **Note:** Refresh the property page to see alerts/updates. Alerts are time-sensitive — a
   > stop alert must be recorded after the start alert.

See [Add a property alert](/users/subsystems/property/add-a-property-alert) for applying an
alert once the categories above are configured.
