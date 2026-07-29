---
title: Zoning in Southwest PA primer
description: LLM generated discussion of zone boundaries, muni vs. state
published: true
date: 2026-07-29T017:53:37.675Z
tags: 
editor: markdown
dateCreated: 2026-07-29T017:53:37.675Z
---

# Zoning in Southwestern Pennsylvania: A Primer for Spatial Data Modeling

*Prepared for the BoroughForge/CodeNforce slippy-map project (PostGIS + Martin + Node). July 2026. Drafted by Fable 5 on 29-JUL-2026 with ECD edits and comments in the database structure sections. VERIFY all information within using authoritative sources*

---

## 1. The legal architecture: state enablement, municipal exercise

Pennsylvania zoning rests on the **Municipalities Planning Code** (MPC), Act 247 of 1968, as amended (53 P.S. § 10101 et seq.). The MPC is *enabling* legislation: the Commonwealth delegates the police power to zone downward to its municipalities, and the municipality — borough, township, city, or home rule municipality — is the unit that actually enacts, amends, and administers a zoning ordinance. There is no state zoning map, no state zone taxonomy, and no state registry of districts. Each of Pennsylvania's roughly 2,560 municipal jurisdictions that chooses to zone writes its own ordinance and adopts its own map, and each of those maps is a freestanding legal instrument.

Three structural consequences matter for your data model:

**First, zoning is optional.** A municipality is under no obligation to adopt a zoning ordinance, and a meaningful number in rural Southwestern Pennsylvania have not. In an unzoned municipality there is simply no zoning layer to map — though subdivision and land development regulation (SALDO), building codes under the Uniform Construction Code, floodplain regulation, and nuisance ordinances may all still apply. Your schema needs to represent "this municipality has no zoning ordinance" as a first-class fact, distinct from "we have not yet acquired this municipality's data."

**Second, counties can zone only into the vacuum.** Under the MPC, a county may adopt a county zoning ordinance, but it applies *only* within municipalities that have no ordinance of their own, and it automatically recedes when a municipality enacts one. Neither Allegheny County nor Westmoreland County operates a county zoning ordinance to my knowledge, so in practice an unzoned township in either county is genuinely unzoned — but verify this with each county planning department before hardcoding the assumption, because the mechanism exists in law and county postures can change.

**Third, Pittsburgh is outside the MPC.** The MPC does not apply to cities of the first and second class — Philadelphia and Pittsburgh. Pittsburgh zones under its own enabling authority through Title Nine of the Pittsburgh Code of Ordinances. Its district taxonomy, procedures, and map maintenance practices differ in kind from every other Allegheny County municipality. If your grant scope includes the city, treat it as its own subsystem with its own ingestion path; the city publishes reasonably good GIS zoning data (available through the WPRDC and the city's open data channels), which is more than can be said for most boroughs.

### State-level constraints on the municipal power

Although municipalities hold the pen, the Commonwealth constrains what they may write, and a few of these constraints occasionally surface in map data:

The MPC itself forbids certain exclusions — ordinances generally cannot prohibit forestry across all districts, cannot exclude no-impact home-based businesses from residential districts, and must provide for a fair share of housing types (the exclusionary-zoning doctrine developed in cases like *Surrick v. Zoning Hearing Board*, 382 A.2d 105 (Pa. 1977)). Agricultural operations receive protection under the Right to Farm Act and ACRE (Act 38 of 2005). Oil and gas is a live wire in this region: Act 13 of 2012 attempted to preempt municipal zoning of unconventional gas development statewide, and the Pennsylvania Supreme Court struck the preemption provisions in *Robinson Township v. Commonwealth*, 83 A.3d 901 (Pa. 2013), returning drilling siting to municipal zoning — which is why you will see gas-specific overlay districts and use provisions scattered across Washington, Westmoreland, and southern Allegheny County ordinances. Floodplain regulation under Act 166 of 1978 and the NFIP produces near-universal floodplain overlay districts whose geometry is derived from FEMA data rather than drawn by the municipality. Airport hazard zoning creates height-limitation overlays around AGC, PIT, and the smaller fields.

The MPC also imposes a **uniformity requirement**: regulations must be uniform within a district. This is why zoning is fundamentally a *map plus text* system — the map assigns territory to districts; the text assigns rules to districts; and the two are jointly adopted as one ordinance. Neither is authoritative without the other.

### Procedural machinery you will feel downstream

Rezonings (map amendments) are enacted by ordinance after public hearing, which means every municipality's zoning map is really a base map plus a chronological stack of amendment ordinances. Small municipalities frequently never redraw the composite map — the "current" map exists only as the 1994 adopted map plus fourteen amending ordinances, each describing a rezoned area by metes and bounds or by tax parcel reference in prose. Pennsylvania also has a distinctive **curative amendment** procedure (MPC §§ 609.1, 916.1) by which a landowner who proves an ordinance substantively invalid can effectively force site-specific relief; the resulting map changes can look like spot zoning and carry litigation history worth recording in provenance notes.

---

## 2. Allegheny County versus Westmoreland County

The counties differ less in zoning *law* — both sit under the same MPC — than in institutional texture and data availability.

**Allegheny County** contains 130 municipalities in 745 square miles, one of the most fragmented county polities in the nation. Nearly all of them zone; the county does not. The county's GIS operation is comparatively strong: the parcel fabric, municipal boundaries, and related layers are published through the county GIS portal, PASDA, and the Western Pennsylvania Regional Data Center, in Pennsylvania State Plane South, NAD83, U.S. survey foot (EPSG:2272). What does **not** exist is an authoritative countywide compiled zoning layer — zoning remains per-municipality, and third-party aggregators (ZoningPoint, Zoneomics/Regrid) that offer "Allegheny County zoning" are commercial compilations of varying vintage and license, not official products. Pittsburgh, Mt. Lebanon, and the larger inner-ring municipalities publish digital zoning GIS; many small boroughs have only a PDF or paper map.

**Westmoreland County** has 65 municipalities across a much larger and more rural footprint. A nontrivial share of its rural townships have never adopted zoning. The Westmoreland County Department of Planning and Development administers subdivision and land development review for municipalities lacking their own SALDO and maintains county GIS resources, but again there is no county zoning ordinance and no authoritative compiled zoning layer. Expect a bimodal data landscape: the Route 30 corridor municipalities (Greensburg, Hempfield, Murrysville, North Huntingdon) have professional planning staff and digital data; the rural townships have either no zoning or a single adopted paper map of considerable age.

For both counties, the honest summary is: **parcels are a county product; zoning is a municipal product.** Your ingestion pipeline is therefore per-municipality by construction, and the county axis mostly determines which parcel fabric and municipal boundary layer you snap to.

One further institutional note relevant to your world: councils of governments (TCVCOG among them) are natural aggregation points for member municipalities' ordinances and maps, and a COG relationship is often the fastest path to the actual adopted documents — faster than FOIA-style Right-to-Know requests to thirty separate borough secretaries.

---

## 3. How zone classifiers work — and why "R-1" is a label, not a taxonomy

This is the single most common misconception, so it deserves precision: **there is no hierarchy, no state schema, and no shared semantics behind district codes.** "R-1" is not a subclassification of a formally defined class "R." It is a naming *convention*, inherited from the Euclidean zoning tradition (after *Village of Euclid v. Ambler Realty*, 272 U.S. 365 (1926)), in which municipalities happen to prefix residential districts with R, commercial with C or B, industrial with I or M, and append a number that usually — but not reliably — tracks increasing density or intensity. Municipality A's R-1 might require one-acre single-family lots; Municipality B's R-1 might permit townhouses; Municipality C might call its lowest-density district "R-A," "S," "Conservation," or "Rural Resource." The code has meaning only inside its own ordinance.

The design consequence: the natural key for a zoning district is the compound **(municipality, district_code)**, and the display name and rules attach to that pair, never to the code alone. If you want cross-municipal comparability — coloring the map by "residential vs. commercial vs. industrial," which any regional viewer needs — that is a *derived, curated* attribute you assign during ingestion, not something present in the source data. Precedents for such a normalization layer include the APA's Land Based Classification Standards (LBCS, a multidimensional land-use classification you can adapt), the National Zoning Atlas methodology (which is currently analyzing all 2,560 Pennsylvania jurisdictions with a standardized characteristic set), and commercial schemes like the Zoneomics/Regrid type–subtype model (Residential → Single Family / Two Family / Multi Family / Mobile Home Park, etc.). Store the verbatim ordinance code, the ordinance's full district name, and your normalized category as three separate columns; never overwrite the local code with the normalized one.

Within a single ordinance, districts do come in structurally distinct *kinds*, and this distinction is load-bearing for geometry:

**Base districts** partition the municipality's territory. Every point in a fully zoned municipality lies in exactly one base district. This is the layer people mean by "the zoning map."

**Overlay districts** are supplemental regulation stacked atop base districts: floodplain overlays, riverfront overlays, historic districts, airport height overlays, steep-slope overlays, gas-drilling overlays, transit-oriented overlays. A parcel can sit under a base district plus zero-to-several overlays simultaneously. Overlays break any data model in which "zone" is a single-valued attribute of a parcel.

**Floating zones and planned districts** are defined in ordinance text but have no mapped location until a landowner successfully petitions to apply one to a specific tract. The MPC's Planned Residential Development article (Article VII) and Traditional Neighborhood Development article are the statutory versions. A PRD, once approved, is governed by its approved development plan rather than by the underlying district's dimensional rules — meaning the map can show "R-2" while the operative law for that tract is a 1987 approved plan sitting in a filing cabinet. Pittsburgh's specially planned (SP) districts are the big-city analogue.

Finally, remember that a great deal of regulation lives in text with no map expression at all: conditional uses, special exceptions, variances granted by the zoning hearing board, and nonconforming uses (lawful uses predating the ordinance). A user who reads your map as "what is allowed here" will be systematically misled unless the interface signals that the map shows *district assignment*, not *entitlement*.

---

## 4. Zone boundaries and their relationship to parcels: two independent partitions

Here is the rigorous framing, because your question — "will all parcels be part of one and exactly one zone?" — smuggles in an assumption worth surfacing. Zoning districts partition *territory*; parcels partition *ownership*. They are two independent tessellations of the same plane, drawn by different actors, at different times, for different purposes, and maintained on different update cycles. Nothing forces them to align, and the correct relational model between parcels and base districts is therefore **many-to-many with an area-of-intersection attribute**, even though the one-to-one case dominates numerically.

That said, alignment is common because ordinance drafters deliberately run district lines along recognizable features. A typical boundary-interpretation section (nearly every ordinance has one, and you should read it before digitizing) declares that district boundaries follow, in rough order of frequency: lot or parcel lines *as they existed at the date of adoption*; street, alley, or railroad centerlines; right-of-way edges; stream centerlines or municipal boundary lines; and, failing all of those, fixed dimensional offsets ("a line 200 feet from and parallel to the centerline of Route 30") or scaling from the adopted map. These interpretation rules are themselves law: when your digitized line and the scanned map disagree, the ordinance's interpretation section, and ultimately the municipal zoning officer, resolves the ambiguity — not your GIS.

Now the specific sub-questions:

**Do zone lines always follow parcel boundaries?** No. Corridor zoning by depth-from-highway is the classic generator of **split-zoned parcels**: a commercial district defined as "300 feet deep along both sides of the arterial" slices through every deep residential lot backing the corridor. Split zoning is common enough in SW PA's ribbon-development corridors (Routes 8, 19, 30, 51, 286) that it must be a supported case, not an exception path.

**Can parcels and zones drift out of sync?** Systematically, yes, and in one direction: the zoning map is legally frozen at adoption while the parcel fabric churns continuously. A district line that followed a lot line in 1978 now bisects the parcel created by a 2009 consolidation. The county reassessment office also adjusts parcel geometry for mapping accuracy without any legal event occurring on the ground, so even a "parcel-line-following" district boundary digitized against the 1995 fabric will misalign with the 2026 fabric by several feet everywhere. Treat parcel–zone congruence as an empirical property to be computed (with a sliver tolerance), never as an invariant to be assumed.

**Do zone lines respect municipal boundaries?** Legally, absolutely: a municipality's zoning power ends at its border, so every zoning district is strictly contained within one municipality, and the municipal boundary is a hard clip line for each ordinance's map. But three practical wrinkles follow. Adjacent municipalities' maps share no semantics — an "R-1/I-2" adjacency across a borough line is legally meaningless friction, and your regional map will display such discontinuities everywhere, correctly. Geometrically, two municipalities digitizing against different base maps will produce gaps and overlaps along their shared border; you should clip every municipality's zoning to a single authoritative municipal boundary layer (the county's, or PennDOT's/PASDA's statewide layer — and note these sources disagree with each other by feet-to-tens-of-feet in places, so pick one and record the choice). And parcels themselves occasionally straddle municipal lines in the county fabric, which means a single parcel can legitimately hold district assignments from two different ordinances.

**Are rights-of-way and water zoned?** Ordinance-dependent. Many maps run districts to street centerlines (so ROW is zoned); others leave public ROW and riverbeds unmapped, producing legitimate holes in the base-district coverage. Decide explicitly whether your compiled layer preserves those holes or fills them, and record which convention each source municipality uses.

---

## 5. Edge cases to design for

Gathering the preceding threads plus a few not yet mentioned, the cases your schema and rendering must survive are: split-zoned parcels; multi-overlay stacking (base district plus N overlays, where overlays overlap each other); unzoned municipalities (real absence) versus unacquired municipalities (missing data); Pittsburgh's non-MPC regime and its SP/planned districts; floating zones with no mapped extent; PRD/approved-plan tracts where the mapped district is no longer the operative regulation; map amendments with effective dates — including recently enacted rezonings not yet reflected in any published map, and rezonings under active court challenge; text–map conflicts resolved by boundary-interpretation rules rather than geometry; municipalities whose only "map" is a hand-drawn or blueline paper original from the 1960s–80s, where digitization is an act of legal interpretation, not tracing; vacated streets whose centerline-following district boundary now floats through the middle of a merged parcel; conditional-use and special-exception regimes invisible to the map; and joint or cooperative zoning — the MPC permits two or more municipalities to adopt a joint ordinance administered by a joint planning entity, in which case one ordinance and one map span multiple municipal territories, inverting your one-ordinance-per-municipality assumption. Joint ordinances are rare but exist in Pennsylvania; check whether any of your target municipalities participate in one before you bake the assumption into a uniqueness constraint.

One more that bites regional mapping specifically: **the same district code recurring across municipalities with different meanings will collide in any legend, symbology table, or tile attribute keyed on code alone.** Every join, style rule, and API response must carry the municipality identifier alongside the code.

---

## 6. Encoding standards and a recommended schema

There is no binding governmental standard for zoning geodata — no FGDC content standard, no OGC schema, no Pennsylvania mandate. What exists is a set of reference practices: the APA's LBCS for land-use classification; the National Zoning Atlas methodology for standardized district characterization (their Pennsylvania project covering all 2,560 jurisdictions is worth watching as both a comparable and a possible data source); ISO 19115/FGDC CSDGM for metadata if your grant requires formal metadata records; and the general municipal-GIS practice patterns visible in mature publishers like Pittsburgh and Philadelphia. From those, here is a synthesis fitted to your stack:

**Layer separation.** Model at minimum three geometry tables: `zoning_base` (polygons; within each municipality, no overlaps, gaps only where the source map genuinely leaves territory unmapped), `zoning_overlay` (polygons; overlaps permitted with base and with each other; one row per overlay-district instance, typed by overlay kind), and a `municipality` reference table carrying the zoning status enum (zoned / unzoned / joint-ordinance-member / unknown) and the authoritative boundary geometry you clip against. A fourth table for PRD/approved-plan footprints pays for itself later.

**Attributes on every zoning feature.** The compound natural key (`muni_id`, `district_code`); the ordinance's verbatim district name; your normalized category and subcategory (curated, documented mapping table); ordinance citation and adopting/amending ordinance numbers with dates; `effective_start` and nullable `effective_end` so superseded geometry is closed out rather than deleted (this bitemporal-lite pattern is the same discipline you already apply elsewhere, and it is what lets the map answer "what was the zoning here in 2023" during an enforcement dispute — directly relevant to CodeNforce's domain); source-document reference (URL, scan filename, or ordinance book page); digitization method and source scale; capture date; and a confidence or quality grade, because a district traced from a 1:24,000 hand-drawn map does not deserve the same epistemic weight as a municipality-supplied shapefile.

**Geometry discipline.** Store in EPSG:2272 to match the Allegheny parcel fabric (or store 4326 and keep a 2272 expression index — but matching the fabric's native CRS avoids reprojection noise in the very snapping operations where feet matter). Enforce `ST_IsValid` via CHECK constraint; run per-municipality topology validation (coverage cleanliness) as an ingestion gate rather than trusting sources; snap district boundaries to the chosen municipal boundary layer and, where the ordinance says a line follows lot lines, snap to the parcel fabric *and record that you did so and against which fabric vintage*. For Martin, serve from a generalized/`ST_Subdivide`d tile source or function layers so the big rural polygons don't wreck tile generation, and key tile feature properties on (`muni_id`, `district_code`, normalized category) so client styling works regionally.

**Parcel linkage as a derived product.** Compute a `parcel_zone` intersection table (`parcel_id`, `zone_feature_id`, `intersection_area`, `pct_of_parcel`) with a sliver-suppression threshold (intersections below, say, 1% of parcel area or a few hundred square feet are almost always registration noise between the two fabrics, not real split zoning — but keep them queryable rather than deleting, so genuine corridor splits near the threshold can be reviewed). Refresh this table whenever either fabric updates; never treat it as source data.

**Provenance and disclaimer.** Every published view should state that the GIS layer is a representation for reference; the officially adopted zoning map and ordinance text control, and boundary determinations are made by the municipal zoning officer. This is standard municipal practice (the WPRDC-style as-is disclaimer is the local template) and it is also simply true.

---

## 7. What you did not ask but should be pricing in

**Acquisition is the project.** The cartography and PostGIS work is the small half. The large half is obtaining, for each municipality, the currently effective ordinance text, the adopted map, and the amendment history — from a population of sources ranging from eCode360-hosted codifications with ArcGIS layers down to a paper map behind the borough secretary's desk. Budget per-municipality effort accordingly, sequence by data quality (municipality-supplied GIS first, PDF georeferencing second, paper digitization last), and use the COG relationship as your acquisition channel where it exists.

**Currency has no push feed.** No mechanism notifies you when a municipality rezones. A sustainable map needs a maintenance loop — periodic ordinance checks, or better, an arrangement whereby member municipalities forward adopted ordinances, which is precisely the kind of standing relationship a COG-anchored code-enforcement platform is positioned to formalize. Consider making "amendment intake" an explicit, funded workflow rather than an aspiration; it is also a natural future CodeNforce workflow-builder use case.

**Zoning is not land use.** Allegheny County publishes a land-use layer derived from aerial interpretation; it describes what is physically on the ground, while zoning describes what regulation applies. They correlate loosely at best. Keep the concepts, and the layers, strictly separate in both schema and UI language, because conflating them is the most common analytical error in this domain.

**Symbology should key on your normalized category, labels on the local code.** Regional legibility requires the curated taxonomy; local fidelity requires the verbatim code. Render fill by category, label by code, and expose both plus the district name on feature click.

**Decide your falsifiable acceptance criteria per municipality.** For example: base-district coverage tiles the municipal territory within tolerance; every district code on the map appears in the ordinance text and vice versa; total district area equals municipal area minus documented unmapped ROW/water. These checks catch digitization errors mechanically and give the grant deliverable an auditable quality statement.

---

## Selected references

Pennsylvania Municipalities Planning Code, Act 247 of 1968, 53 P.S. § 10101 et seq. (esp. Articles VI, VII, VII-A, and §§ 609.1, 916.1). *Robinson Township v. Commonwealth*, 83 A.3d 901 (Pa. 2013). *Surrick v. Zoning Hearing Board of Upper Providence Township*, 382 A.2d 105 (Pa. 1977). Governor's Center for Local Government Services, *Pennsylvania Planning Series* (esp. No. 4, *Zoning*) — the standard practitioner references on MPC zoning practice. National Zoning Atlas, Pennsylvania project (zoningatlas.org/pennsylvania). APA, Land Based Classification Standards. Allegheny County GIS / PASDA / WPRDC for parcel fabric, municipal boundaries, and land-use layers (State Plane PA South, U.S. survey foot, EPSG:2272). Westmoreland County Department of Planning and Development for county GIS and subdivision administration.
