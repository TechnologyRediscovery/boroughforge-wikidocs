---
title: Facelet / XHTML page reference
description: Quick tools and tricks when building facelets 
published: true
date: 2026-02-25T13:27:53.560Z
tags: 
editor: markdown
dateCreated: 2025-12-15T20:06:57.029Z
---

# JSF / Facelet tricks

## Dialog errors
Prevent a dialog from closing if there are validation errors:
```
<p:commandButton   ...the ususal jazz...
   oncomplete="if (!args.validationFailed) {PF('violation-add-dialog-var').hide();}"
                                            update="violation-add-form
                                            violation-growl-form"/>
```

## Custom components

## **Complete Reference Table**

| EL Expression | What It Returns | Use Case |
|---------------|-----------------|----------|
| `#{cc.attrs.propertyName}` | Value of attribute `propertyName` | Access passed-in data |
| `#{cc.clientId}` | Full client ID with prefixes | Unique widget vars, form IDs |
| `#{cc.id}` | Simple ID (if assigned) | Update targets within component |
| `#{cc.parent}` | Parent UIComponent | Advanced component tree manipulation |
| `#{cc.namingContainer}` | The composite as NamingContainer | Advanced framework use |

---

## Auto expanding advanced fields on search
Thanks to Sonnet 4.5...
Add this function to the top of the page:
```js
 <script type="text/javascript">
        function handleAdvancedPanelAutoExpand(autoExpand) {
            
            var panel = PF('prop-search-controls-panel-var');
            
            if (panel) {
                // Handle undefined or missing value
                if (autoExpand === undefined || autoExpand === null) {
                    panel.expand();
                } else if (autoExpand === true || autoExpand === 'true') {
                    panel.expand();
                } else {
                    panel.collapse();
                }
            } 
        }
    </script>
```
Then use this in the change listener:
```xml
<p:selectOneMenu id="prop-search-query-som"
                 tabindex="1"
                 value="#{propertySearchBB.querySelected}"
                 style="width: 100%"
                 >
    <f:converter converterId="bOBQueryConverter"/>

    <f:selectItem itemLabel="select a query..."
                  noSelectionOption="true"
                  itemDisabled="true"
                  />
    <f:selectItems id="prop-search-query-si"
                   value="#{propertySearchBB.queryList}"
                   var="ql"
                   itemValue="#{ql}"
                   itemLabel="#{ql.queryTitle}" 
                   />
    <p:ajax update="prop-search-params-form
            query-selected-description
            prop-search-messages-form"
            listener="#{propertySearchBB.changeQuerySelected}"
            oncomplete="handleAdvancedPanelAutoExpand(args.autoExpandAdvanced)"
            />
</p:selectOneMenu>
```

And this in the backing bean

```java
 /**
     * Listener method for changes in the selected query;
     * Updates search params and UI updates based on this changed value
     */
    public void changeQuerySelected(){
        System.out.println("PropertySearchBB.changeQuerySelected | querySelected: " + querySelected.getQueryTitle());
        configureParameters();
        
        // Pass autoExpandAdvanced flag to client for advanced panel control
        PrimeFaces.current().ajax().addCallbackParam("autoExpandAdvanced", 
            querySelected.getQueryName().isAutoExpandAdvanced());
    } 
```