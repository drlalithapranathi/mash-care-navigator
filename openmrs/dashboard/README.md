# Dashboard placement of the FIB-4 widget

The FIB-4 widget is a coreapps dashboard fragment
(`web/module/fragments/dashboardwidgets/fib4screening.gsp`). *Where* it appears on
the clinician-facing patient dashboard is a coreapps configuration, separate from
the widget's own markup.

## Current placement — below General Actions (#40)

The widget renders in the **right column, below the General Actions panel**, by a
one-line fragment include in coreapps' clinician patient page
`web/module/pages/clinicianfacing/patient.gsp`, inside the right column
(`col-12 col-lg-3`) immediately after the action-section:

```gsp
            <% } %>
            <% if (patient) { %>
                <div class="mash-fib4-dashboard-slot" style="margin-top:10px">
                    ${ ui.includeFragment("coreapps", "dashboardwidgets/fib4screening", [patient: patient, patientId: patient.patient.id]) }
                </div>
            <% } %>
        </div>
    </div>
```

Because the widget is now included directly by the page, its app-framework
registration `apps/fib4Screening_app.json` is emptied to `[]` so it does **not**
also render as a first-column extension (which would double it):

```json
[]
```

## Applying it

Both edits are surgical single-entry replacements into the coreapps OMOD, chained
through `openmrs/deploy/repack-omod.py` (same mechanism as the widget), then the
patched OMOD is deployed and `mash-openmrs-app` restarted:

```sh
python3 openmrs/deploy/repack-omod.py BASE.omod patient.gsp    tmp.omod   --gsp-rel web/module/pages/clinicianfacing/patient.gsp
python3 openmrs/deploy/repack-omod.py tmp.omod  fib4app-empty.json OUT.omod --gsp-rel apps/fib4Screening_app.json
```

## Reverting to a dashboard column

To move it back into a content column instead, drop the `patient.gsp` include and
restore `apps/fib4Screening_app.json` to an app-framework extension:

```json
[
  {
    "id": "mashcarenavigator.fib4Screening",
    "description": "MASH Care Navigator: FIB-4 MASLD/MASH screening widget",
    "order": 1,
    "extensions": [
      {
        "id": "mashcarenavigator.fib4Screening.column",
        "appId": "mashcarenavigator.fib4Screening",
        "extensionPointId": "patientDashboard.firstColumnFragments",
        "extensionParams": { "provider": "coreapps", "fragment": "dashboardwidgets/fib4screening" }
      }
    ]
  }
]
```

Change `extensionPointId` to `patientDashboard.secondColumnFragments` and/or bump
`order` to move it between columns / lower in a column.
