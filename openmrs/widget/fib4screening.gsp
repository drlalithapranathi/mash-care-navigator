<div id="fib4-screening-widget">
    <div style="padding:10px">
        <span style="color:#888">Loading FIB-4...</span>
    </div>
</div>

<script type="text/javascript">
jq(function(){
    var patientUuid = "${patient.patient.uuid}";
    if(!patientUuid) return;

    var base = "/" + OPENMRS_CONTEXT_PATH + "/ws/rest/v1";

    // Observation concept UUIDs - used to FETCH existing lab results
    var UUIDS = {
        AST:  "5914052f-e777-4efc-949b-0dee321ae55f",
        ALT:  "29a09214-cfd4-4db9-898e-f2a3e6f08feb",
        PLAT: "8575950e-90bf-4530-9595-deebbdf2cdde",
        DEFERRED: "87fcf943-1e0c-4b09-8771-23cae2affda3",
        FIB4_SCORE: "fd064e9b-a811-412d-9000-b7134db9d020",
        FIB4_CATEGORY: "a27e88f2-ab54-434c-952b-be714d1af6b0"
    };

    // Orderable panel concept UUIDs (LOINC-mapped) - missing-labs ordering
    var ORDER_PANELS = {
        CBC:     { uuid: "30b29cc7-3565-11f1-a0a1-92c09ef48e9b", label: "CBC (Complete Blood Count)", covers: ["PLAT"] },
        HEPATIC: { uuid: "353d3e7b-3565-11f1-a0a1-92c09ef48e9b", label: "Hepatic Function Panel (LFT)", covers: ["AST", "ALT"] }
    };

    // Risk-level orderables (FIB-4 stratification follow-up)
    var RISK_ORDERS = {
        VCTE:    { uuid: "cb9450cf-bb90-4600-9116-b7c1ab8ee5b3", label: "FibroScan (VCTE)",
                   sublabel: "LOINC 79961-7 &middot; Vibration-Controlled Transient Elastography",
                   icon: "&#x1F4DD;" },
        ELF:     { uuid: "cd75cf42-ef4b-4d15-9ea4-ea12eca9e568", label: "Enhanced Liver Fibrosis (ELF)",
                   sublabel: "LOINC 95942-6 &middot; ELF blood panel",
                   icon: "&#x1F4DD;" },
        CONSULT: { uuid: "f682c646-b597-4cd4-8282-4191e0eb040b", label: "Gastroenterology / Hepatology consult",
                   sublabel: "High-risk MASLD &middot; possible advanced fibrosis / cirrhosis",
                   icon: "&#x1F6A8;" }
    };

    var LAB_NAMES = {
        AST:  "AST (Aspartate Aminotransferase)",
        ALT:  "ALT (Alanine Aminotransferase)",
        PLAT: "Platelet Count"
    };

    // Order type, care setting, encounter type, visit type UUIDs
    var TEST_ORDER_TYPE   = "52a447d3-a64a-11e3-9aeb-50e549534c5e";
    var OUTPATIENT        = "6f0c9a92-6f24-11e3-af88-005056821db0";
    var VISIT_NOTE        = "d7151f82-c1f3-4152-a605-2f9ea7414a79";
    var FACILITY_VISIT    = "7b0f5697-27e3-40c4-8bae-f4049abfb4ed";

    // Age-adjusted FIB-4 cutoffs (McPherson 2017 + AGA Clinical Care Pathway)
    var FIB4_LOWER_DEFAULT = 1.3;
    var FIB4_LOWER_OVER65  = 2.0;
    var FIB4_UPPER         = 2.67;

    function getLowerCutoff(age){
        return (age != null && age >= 65) ? FIB4_LOWER_OVER65 : FIB4_LOWER_DEFAULT;
    }

    // ---- Reusable order placement (single concept) ----
    function placeOrderForConcept(conceptUuid, label, statusEl, btnEl, onSuccess){
        statusEl.html('<span style="color:#888">Checking session...</span>');
        jq.getJSON(base + "/session", function(session){
            var userUuid = session.user ? session.user.uuid : null;
            if(!userUuid){
                statusEl.html('<span style="color:red">Could not get current user session.</span>');
                if(btnEl) btnEl.prop("disabled", false);
                return;
            }
            jq.getJSON(base + "/provider?user=" + userUuid + "&v=default", function(provData){
                var ordererUuid = provData.results && provData.results.length > 0
                    ? provData.results[0].uuid : null;
                if(!ordererUuid){
                    statusEl.html('<span style="color:red">No provider linked to current user. Cannot place order.</span>');
                    if(btnEl) btnEl.prop("disabled", false);
                    return;
                }
                statusEl.html('<span style="color:#888">Checking for active visit...</span>');
                jq.getJSON(base + "/visit?patient=" + patientUuid + "&includeInactive=false&v=default", function(visitData){
                    var visitUuid = (visitData.results && visitData.results.length > 0) ? visitData.results[0].uuid : null;

                    var encPayload = {
                        patient: patientUuid,
                        encounterType: VISIT_NOTE,
                        orders: [{
                            type: "testorder",
                            action: "NEW",
                            patient: patientUuid,
                            concept: conceptUuid,
                            careSetting: OUTPATIENT,
                            orderer: ordererUuid,
                            orderType: TEST_ORDER_TYPE
                        }]
                    };

                    var doPost = function(){
                        statusEl.html('<span style="color:#888">Placing order...</span>');
                        jq.ajax({
                            url: base + "/encounter",
                            type: "POST",
                            contentType: "application/json",
                            data: JSON.stringify(encPayload),
                            success: function(){
                                statusEl.html(
                                    '<span style="color:#2e7d32;font-weight:600">&#x2713; Ordered: ' + label + '</span>'
                                );
                                if(onSuccess) onSuccess();
                            },
                            error: function(xhr){
                                var msg = "Order failed.";
                                try { msg = JSON.parse(xhr.responseText).error.message; } catch(e){}
                                statusEl.html('<span style="color:red">Error: ' + msg + '</span>');
                                if(btnEl) btnEl.prop("disabled", false);
                            }
                        });
                    };

                    if(visitUuid){
                        encPayload.visit = visitUuid;
                        doPost();
                    } else {
                        statusEl.html('<span style="color:#888">No active visit. Creating visit...</span>');
                        jq.ajax({
                            url: base + "/visit",
                            type: "POST",
                            contentType: "application/json",
                            data: JSON.stringify({
                                patient: patientUuid,
                                visitType: FACILITY_VISIT,
                                startDatetime: new Date().toISOString()
                            }),
                            success: function(newVisit){
                                encPayload.visit = newVisit.uuid;
                                doPost();
                            },
                            error: function(){
                                statusEl.html('<span style="color:red">Could not start a visit; order not placed.</span>');
                                if(btnEl) btnEl.prop("disabled", false);
                            }
                        });
                    }
                });
            });
        });
    }

    // Render a single risk-level order action row (with active-order check)
    function renderRiskAction(orderDef, levelColors){
        var rowId = "risk-action-" + orderDef.uuid;
        var statusId = rowId + "-status";
        var btnId = rowId + "-btn";

        var html =
            '<div id="' + rowId + '" style="margin-bottom:6px;padding:8px 10px;background:#fff;border:1px solid ' + levelColors.border + ';border-radius:4px">' +
                '<div style="display:flex;align-items:center;gap:8px">' +
                    '<div style="flex:1">' +
                        '<div style="font-size:13px;font-weight:600;color:' + levelColors.text + '">' +
                            orderDef.icon + ' ' + orderDef.label +
                        '</div>' +
                        '<div style="font-size:11px;color:#666;margin-top:2px;font-weight:400">' + orderDef.sublabel + '</div>' +
                    '</div>' +
                    '<button id="' + btnId + '" style="background:' + levelColors.btnBg + ';color:#fff;border:none;padding:6px 12px;border-radius:4px;cursor:pointer;font-size:12px;font-weight:600;white-space:nowrap">' +
                        '&#x2295; Place Order' +
                    '</button>' +
                '</div>' +
                '<div id="' + statusId + '" style="margin-top:5px;font-size:12px"></div>' +
            '</div>';

        return { html: html, statusId: statusId, btnId: btnId, def: orderDef };
    }

    // After rows are in the DOM, wire up active-order checks + button handlers
    function attachRiskAction(row){
        var statusEl = jq("#" + row.statusId);
        var btnEl = jq("#" + row.btnId);

        // Disable until the active-order check returns, so a fast click can't
        // place an order the guard would have blocked (#35).
        btnEl.prop("disabled", true);
        jq.getJSON(base + "/order?patient=" + patientUuid + "&concept=" + row.def.uuid + "&v=default")
          .done(function(orderData){
            var results = (orderData && orderData.results) || [];
            var hasActive = results.some(function(o){ return !o.voided && !o.dateStopped && !o.autoExpireDate; });
            if(hasActive){
                btnEl.prop("disabled", true).css({"background":"#bdbdbd","cursor":"not-allowed"}).text("Already ordered");
                statusEl.html('<span style="color:#e65100">&#x23F3; Awaiting result</span>');
            } else {
                btnEl.prop("disabled", false);
            }
          })
          .fail(function(){ btnEl.prop("disabled", false); });

        btnEl.on("click", function(){
            btnEl.prop("disabled", true).text("Ordering...");
            placeOrderForConcept(row.def.uuid, row.def.label, statusEl, btnEl, function(){
                btnEl.css({"background":"#bdbdbd","cursor":"not-allowed"}).text("Ordered");
            });
        });
    }

    // ---- Record a "deferred / declined follow-up" decision as a text obs (#8) ----
    function recordDeferral(statusEl, onSuccess){
        statusEl.html('<span style="color:#888">Recording...</span>');
        jq.ajax({
            url: base + "/obs",
            type: "POST",
            contentType: "application/json",
            data: JSON.stringify({
                person: patientUuid,
                concept: UUIDS.DEFERRED,
                obsDatetime: new Date().toISOString(),
                value: "deferred"
            }),
            success: function(){ if(onSuccess) onSuccess(); },
            error: function(xhr){
                var msg = "Could not record.";
                try { msg = JSON.parse(xhr.responseText).error.message; } catch(e){}
                statusEl.html('<span style="color:red">Error: ' + msg + '</span>');
            }
        });
    }

    // Persist the FIB-4 score + risk category as obs for trending, deduped so a
    // repeat chart view doesn't spam identical obs — only writes when the score
    // changes from the latest stored value (#23).
    function persistFib4(score, category){
        var rounded = Math.round(score * 100) / 100;
        jq.getJSON(base + "/obs?patient=" + patientUuid + "&concept=" + UUIDS.FIB4_SCORE + "&v=full")
          .done(function(data){
            var results = ((data && data.results) || []).filter(function(o){ return !o.voided; });
            results.sort(function(a, b){ return new Date(b.obsDatetime) - new Date(a.obsDatetime); });
            var latest = results.length ? Number(results[0].value) : null;
            if(latest !== null && Math.abs(latest - rounded) < 0.005) return;   // unchanged — skip
            postFib4Obs(UUIDS.FIB4_SCORE, rounded);
            postFib4Obs(UUIDS.FIB4_CATEGORY, category);
          });
    }
    function postFib4Obs(concept, value){
        jq.ajax({
            url: base + "/obs", type: "POST", contentType: "application/json",
            data: JSON.stringify({ person: patientUuid, concept: concept, obsDatetime: new Date().toISOString(), value: value })
        });
    }

    // Wire the "defer follow-up" link and surface any prior deferral on load.
    function attachDeferLink(){
        var link = jq("#fib4-defer-link");
        if(!link.length) return;
        var statusEl = jq("#fib4-defer-status");

        jq.getJSON(base + "/obs?patient=" + patientUuid + "&concept=" + UUIDS.DEFERRED + "&v=full", function(data){
            var results = ((data && data.results) || []).filter(function(o){ return !o.voided && o.value; });
            if(results.length){
                results.sort(function(a,b){ return new Date(b.obsDatetime) - new Date(a.obsDatetime); });
                var d = new Date(results[0].obsDatetime);
                statusEl.html('<span style="color:#777">&#x23F8; Deferred on ' + d.toLocaleDateString() + '</span>');
            }
        });

        link.on("click", function(e){
            e.preventDefault();
            link.css({"pointer-events":"none","opacity":"0.5"});
            recordDeferral(statusEl, function(){
                statusEl.html('<span style="color:#777;font-weight:600">&#x23F8; Follow-up deferred</span>');
                link.hide();
            });
        });
    }

    // --- Step 1: Fetch the latest AST / ALT / platelets, querying by concept so
    // the newest value is found even on charts with many observations (issue #9). ---
    function pickLatestObs(resp){
        var results = (resp && resp[0] && resp[0].results) ? resp[0].results : [];
        var latest = null;
        results.forEach(function(o){
            if(o.value == null || o.voided) return;
            if(!latest || new Date(o.obsDatetime) > new Date(latest.obsDatetime)) latest = o;
        });
        return latest;   // full obs (value + obsDatetime) or null (#34)
    }

    // Concept/order UUIDs are overridable via global properties (issue #7); the
    // hardcoded values above are the fallback if a GP is unset or lookup fails.
    function applyGpOverrides(gp){
        var m = {};
        (((gp && gp.results)) || []).forEach(function(s){
            if(s.property && s.value != null && s.value !== "") m[s.property] = s.value;
        });
        if(m["mashmasld.concept.ast"])   UUIDS.AST  = m["mashmasld.concept.ast"];
        if(m["mashmasld.concept.alt"])   UUIDS.ALT  = m["mashmasld.concept.alt"];
        if(m["mashmasld.concept.plat"])  UUIDS.PLAT = m["mashmasld.concept.plat"];
        if(m["mashmasld.concept.deferred"]) UUIDS.DEFERRED = m["mashmasld.concept.deferred"];
        if(m["mashmasld.concept.fib4score"])    UUIDS.FIB4_SCORE    = m["mashmasld.concept.fib4score"];
        if(m["mashmasld.concept.fib4category"]) UUIDS.FIB4_CATEGORY = m["mashmasld.concept.fib4category"];
        if(m["mashmasld.order.cbc"])     ORDER_PANELS.CBC.uuid     = m["mashmasld.order.cbc"];
        if(m["mashmasld.order.hepatic"]) ORDER_PANELS.HEPATIC.uuid = m["mashmasld.order.hepatic"];
        if(m["mashmasld.order.vcte"])    RISK_ORDERS.VCTE.uuid     = m["mashmasld.order.vcte"];
        if(m["mashmasld.order.elf"])     RISK_ORDERS.ELF.uuid      = m["mashmasld.order.elf"];
        if(m["mashmasld.order.consult"]) RISK_ORDERS.CONSULT.uuid  = m["mashmasld.order.consult"];
    }

    // Coerce an obs value to a finite positive number, else null (#12).
    function validPositive(x){
        var n = (x === null || x === undefined || x === "") ? NaN : Number(x);
        return (isFinite(n) && n > 0) ? n : null;
    }

    function loadLabsAndRender(){
    jq.when(
        jq.getJSON(base + "/obs?patient=" + patientUuid + "&concept=" + UUIDS.AST  + "&v=full"),
        jq.getJSON(base + "/obs?patient=" + patientUuid + "&concept=" + UUIDS.ALT  + "&v=full"),
        jq.getJSON(base + "/obs?patient=" + patientUuid + "&concept=" + UUIDS.PLAT + "&v=full")
    ).done(function(astResp, altResp, platResp){
        var astObs  = pickLatestObs(astResp);
        var altObs  = pickLatestObs(altResp);
        var platObs = pickLatestObs(platResp);
        var ast  = validPositive(astObs  && astObs.value);
        var alt  = validPositive(altObs  && altObs.value);
        var plat = validPositive(platObs && platObs.value);

        var el = jq("#fib4-screening-widget");

        // --- Missing labs case ---
        if(!ast || !alt || !plat){
            var missing = [];
            if(!ast)  missing.push("AST");
            if(!alt)  missing.push("ALT");
            if(!plat) missing.push("PLAT");

            var missingNames = missing.map(function(k){ return LAB_NAMES[k]; }).join(", ");

            // Active-order check runs against the PANEL concepts we would place
            // (CBC / Hepatic), not the obs concepts — the order is recorded
            // against the panel, so checking the obs concept never matched (#13).
            var panelsNeeded = [];
            Object.keys(ORDER_PANELS).forEach(function(pk){
                var panel = ORDER_PANELS[pk];
                if(panel.covers.some(function(l){ return missing.indexOf(l) !== -1; })) panelsNeeded.push(panel);
            });

            var orderChecks = panelsNeeded.map(function(panel){
                return jq.getJSON(base + "/order?patient=" + patientUuid + "&concept=" + panel.uuid + "&v=default");
            });

            jq.when.apply(jq, orderChecks).done(function(){
                var responses = panelsNeeded.length === 1 ? [arguments] : Array.prototype.slice.call(arguments);
                var orderedLabs = {};
                panelsNeeded.forEach(function(panel, i){
                    var results = (responses[i][0] && responses[i][0].results) ? responses[i][0].results : [];
                    var hasPending = results.some(function(o){ return !o.voided && !o.dateStopped && !o.autoExpireDate; });
                    if(hasPending) panel.covers.forEach(function(l){ orderedLabs[l] = true; });
                });

                var alreadyOrdered = [];
                var stillMissing = [];
                missing.forEach(function(key){
                    if(orderedLabs[key]) alreadyOrdered.push(LAB_NAMES[key]);
                    else stillMissing.push(key);
                });

                var html = '<div style="padding:8px;background:#f5f5f5;border-left:4px solid #999;border-radius:4px">' +
                    '<strong style="color:#666">Missing Labs</strong><br>' +
                    '<span style="font-size:12px;color:#555">Missing: ' + missingNames + '</span>';

                if(alreadyOrdered.length > 0){
                    html += '<br><span style="font-size:12px;color:#e65100">&#x23F3; Already ordered: ' + alreadyOrdered.join(", ") + '</span>';
                }

                if(stillMissing.length > 0){
                    html += '<br><br><button id="fib4-order-btn" style="background:#1a78c2;color:#fff;border:none;padding:7px 14px;border-radius:4px;cursor:pointer;font-size:13px;font-weight:600">' +
                        '&#x2295; Order Missing Labs</button>';
                } else {
                    html += '<br><br><span style="color:#2e7d32;font-weight:600;font-size:13px">&#x2713; All labs already ordered &mdash; awaiting results</span>';
                }

                html += '<div id="fib4-order-status" style="margin-top:6px;font-size:12px"></div></div>' +
                    '<a href="/' + OPENMRS_CONTEXT_PATH + '/owa/mashmasld/index.html?patientId=' + patientUuid + '" ' +
                    'style="display:block;margin-top:8px;color:#009384;font-weight:600;font-size:13px">Open Full Screening &rarr;</a>';

                el.html(html);

                if(stillMissing.length === 0) return;

                jq("#fib4-order-btn").on("click", function(){
                var btn = jq(this);
                var status = jq("#fib4-order-status");
                btn.prop("disabled", true).text("Ordering...");
                status.html('<span style="color:#888">Checking session...</span>');

                jq.getJSON(base + "/session", function(session){
                    var userUuid = session.user ? session.user.uuid : null;
                    if(!userUuid){
                        status.html('<span style="color:red">Could not get current user session.</span>');
                        btn.prop("disabled", false).text("&#x2295; Order Missing Labs");
                        return;
                    }

                    jq.getJSON(base + "/provider?user=" + userUuid + "&v=default", function(provData){
                        var ordererUuid = null;
                        if(provData.results && provData.results.length > 0){
                            ordererUuid = provData.results[0].uuid;
                        }
                        if(!ordererUuid){
                            status.html('<span style="color:red">No provider linked to current user. Cannot place order.</span>');
                            btn.prop("disabled", false).text("&#x2295; Order Missing Labs");
                            return;
                        }

                        status.html('<span style="color:#888">Checking for active visit...</span>');
                        jq.getJSON(base + "/visit?patient=" + patientUuid + "&includeInactive=false&v=default", function(visitData){
                            var visitUuid = null;
                            if(visitData.results && visitData.results.length > 0){
                                visitUuid = visitData.results[0].uuid;
                            }

                            var panelsToOrder = [];
                            Object.keys(ORDER_PANELS).forEach(function(panelKey){
                                var panel = ORDER_PANELS[panelKey];
                                var needed = panel.covers.some(function(labKey){
                                    return stillMissing.indexOf(labKey) !== -1;
                                });
                                if(needed) panelsToOrder.push(panel);
                            });

                            var orders = panelsToOrder.map(function(panel){
                                return {
                                    type: "testorder",
                                    action: "NEW",
                                    patient: patientUuid,
                                    concept: panel.uuid,
                                    careSetting: OUTPATIENT,
                                    orderer: ordererUuid,
                                    orderType: TEST_ORDER_TYPE
                                };
                            });

                            var encounterPayload = {
                                patient: patientUuid,
                                encounterType: VISIT_NOTE,
                                orders: orders
                            };
                            if(visitUuid){
                                encounterPayload.visit = visitUuid;
                            } else {
                                status.html('<span style="color:#888">No active visit. Creating visit...</span>');
                            }

                            var placeOrders = function(encPayload){
                                status.html('<span style="color:#888">Placing orders...</span>');
                                jq.ajax({
                                    url: base + "/encounter",
                                    type: "POST",
                                    contentType: "application/json",
                                    data: JSON.stringify(encPayload),
                                    success: function(resp){
                                        var orderedNames = panelsToOrder.map(function(p){ return p.label; }).join(", ");
                                        status.html(
                                            '<span style="color:#2e7d32;font-weight:600">&#x2713; Orders placed successfully!</span><br>' +
                                            '<span style="color:#555;font-size:11px">Ordered: ' + orderedNames + '</span>'
                                        );
                                        btn.hide();
                                    },
                                    error: function(xhr){
                                        var msg = "Order failed.";
                                        try { msg = JSON.parse(xhr.responseText).error.message; } catch(e){}
                                        status.html('<span style="color:red">Error: ' + msg + '</span>');
                                        btn.prop("disabled", false).text("&#x2295; Order Missing Labs");
                                    }
                                });
                            };

                            if(visitUuid){
                                placeOrders(encounterPayload);
                            } else {
                                jq.ajax({
                                    url: base + "/visit",
                                    type: "POST",
                                    contentType: "application/json",
                                    data: JSON.stringify({
                                        patient: patientUuid,
                                        visitType: FACILITY_VISIT,
                                        startDatetime: new Date().toISOString()
                                    }),
                                    success: function(newVisit){
                                        encounterPayload.visit = newVisit.uuid;
                                        placeOrders(encounterPayload);
                                    },
                                    error: function(){
                                        status.html('<span style="color:red">Could not start a visit; orders not placed.</span>');
                                        btn.prop("disabled", false).text("&#x2295; Order Missing Labs");
                                    }
                                });
                            }
                        });
                    });
                });
                });
            });

            return;
        }

        // --- FIB-4 calculation (with age-adjusted lower cutoff) ---
        // Null-safe: a patient with no birthdate must not emit `var age = ;` (#11).
        var age  = ${patient.patient.age != null ? patient.patient.age : 'null'};
        var ageNum = validPositive(age);
        if(ageNum === null){
            el.html('<div style="padding:10px;background:#f5f5f5;border-left:4px solid #999;border-radius:4px">' +
                '<strong style="color:#666">FIB-4 unavailable</strong><br>' +
                '<span style="font-size:12px;color:#555">Patient age is required to compute FIB-4.</span></div>');
            return;
        }
        age = ageNum;
        var fib4 = (age * ast) / (plat * Math.sqrt(alt));
        if(!isFinite(fib4)){
            el.html('<div style="padding:10px;background:#f5f5f5;border-left:4px solid #999;border-radius:4px">' +
                '<strong style="color:#666">FIB-4 not interpretable</strong><br>' +
                '<span style="font-size:12px;color:#555">Lab values are out of range for a FIB-4 calculation.</span></div>');
            return;
        }

        // #16: FIB-4 assumes chronic, stable disease — guard the inputs that invalidate it.
        if(plat > 1000){
            el.html('<div style="padding:10px;background:#fff3e0;border-left:4px solid #e65100;border-radius:4px">' +
                '<strong style="color:#bf360c">Platelet value out of range</strong><br>' +
                '<span style="font-size:12px;color:#555">Platelets of ' + plat + ' look like an absolute count (unit mismatch); FIB-4 expects ~150&ndash;400 &times;10&sup9;/L. Not shown.</span></div>');
            return;
        }
        if(ast > 500 || alt > 500){
            el.html('<div style="padding:10px;background:#fff3e0;border-left:4px solid #e65100;border-radius:4px">' +
                '<strong style="color:#bf360c">Possible acute hepatocellular injury</strong><br>' +
                '<span style="font-size:12px;color:#555">Markedly elevated transaminases (AST ' + ast + ', ALT ' + alt + '). FIB-4 assumes chronic disease and is not interpretable here &mdash; evaluate for acute injury.</span></div>');
            return;
        }

        var lowerCutoff = getLowerCutoff(age);

        // #34: surface the source draw dates and warn on stale / wide-span inputs.
        var labDateNote = "";
        (function(){
            var ds = [astObs, altObs, platObs].map(function(o){ return o ? new Date(o.obsDatetime) : null; });
            if(ds.indexOf(null) !== -1) return;
            var times = ds.map(function(d){ return d.getTime(); });
            var spanDays = Math.round((Math.max.apply(null, times) - Math.min.apply(null, times)) / 86400000);
            var ageDays  = Math.round((new Date().getTime() - Math.max.apply(null, times)) / 86400000);
            var warn = (spanDays > 180 || ageDays > 365);
            function fmt(d){ return d.toLocaleDateString(); }
            labDateNote =
                '<div style="font-size:11px;color:' + (warn ? "#b71c1c" : "#777") + ';margin-top:2px">' +
                (warn ? "&#x26A0; " : "") +
                'Labs: AST ' + fmt(ds[0]) + ' &middot; ALT ' + fmt(ds[1]) + ' &middot; PLT ' + fmt(ds[2]) +
                (spanDays > 180 ? ' &middot; drawn ' + spanDays + 'd apart' : "") +
                (ageDays > 365 ? ' &middot; latest ' + ageDays + 'd old' : "") +
                '</div>';
        })();

        var color, level, bg, levelKey;
        if(fib4 < lowerCutoff)        { color="#2e7d32"; level="LOW RISK";          bg="#e8f5e9"; levelKey="low"; }
        else if(fib4 <= FIB4_UPPER)   { color="#e65100"; level="INTERMEDIATE RISK"; bg="#fff8e1"; levelKey="intermediate"; }
        else                          { color="#c62828"; level="HIGH RISK";         bg="#ffebee"; levelKey="high"; }

        persistFib4(fib4, levelKey);   // #23: record the score + category (deduped)

        var ageNote = (age != null && age >= 65)
            ? '<span style="font-size:11px;color:#777"> (age &ge;65: low/intermediate cutoff = ' + lowerCutoff.toFixed(1) + ')</span>'
            : '';

        // ---- Risk-level order actions ----
        var riskActionsRows = [];
        var riskActionsHtml = "";
        var deferLinkHtml =
            '<div style="margin-top:4px">' +
            '<a href="#" id="fib4-defer-link" style="font-size:11px;color:#777;text-decoration:underline">Not now &mdash; defer follow-up</a>' +
            ' <span id="fib4-defer-status" style="font-size:11px;margin-left:6px"></span>' +
            '</div>';

        if(levelKey === "intermediate"){
            var colorsAmber = { border: "#ffb74d", text: "#bf360c", btnBg: "#e65100" };
            var rowVcte = renderRiskAction(RISK_ORDERS.VCTE, colorsAmber);
            var rowElf  = renderRiskAction(RISK_ORDERS.ELF,  colorsAmber);
            riskActionsRows.push(rowVcte, rowElf);
            riskActionsHtml =
                '<div style="margin-top:10px;padding:8px;background:#fff8e1;border-left:3px solid #e65100;border-radius:4px">' +
                '<div style="font-size:11px;font-weight:700;color:#bf360c;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px">Recommended actions &middot; FIB-4 ' + lowerCutoff.toFixed(1) + '&ndash;' + FIB4_UPPER + '</div>' +
                rowVcte.html + rowElf.html + deferLinkHtml +
                '</div>';
        }
        else if(levelKey === "high"){
            var colorsRed = { border: "#ef5350", text: "#b71c1c", btnBg: "#c62828" };
            var rowConsult = renderRiskAction(RISK_ORDERS.CONSULT, colorsRed);
            riskActionsRows.push(rowConsult);
            riskActionsHtml =
                '<div style="margin-top:10px;padding:8px;background:#ffebee;border-left:3px solid #c62828;border-radius:4px">' +
                '<div style="font-size:11px;font-weight:700;color:#b71c1c;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px">Urgent &middot; recommended action &middot; FIB-4 &gt;' + FIB4_UPPER + '</div>' +
                rowConsult.html + deferLinkHtml +
                '</div>';
        }

        el.html(
            '<div style="padding:10px;background:'+bg+';border-left:4px solid '+color+';border-radius:4px">' +
            '<strong style="color:'+color+';font-size:20px">'+fib4.toFixed(2)+'</strong> ' +
            '<span style="color:'+color+';font-weight:600">'+level+'</span>' + ageNote + '<br>' +
            '<span style="font-size:12px;color:#666">FIB-4 = ('+age+' &times; '+ast+') / ('+plat+' &times; &radic;'+alt+')</span>' +
            labDateNote +
            '</div>' +
            riskActionsHtml +
            '<a href="/' + OPENMRS_CONTEXT_PATH + '/owa/mashmasld/index.html?patientId=' + patientUuid + '" ' +
            'style="display:block;margin-top:8px;color:#009384;font-weight:600;font-size:13px">View Full MASLD Screening &rarr;</a>'
        );

        // Wire up risk-action buttons after they are in the DOM
        riskActionsRows.forEach(attachRiskAction);
        attachDeferLink();
    })
    .fail(function(){
        jq("#fib4-screening-widget").html(
            '<div style="padding:10px;color:#999;font-size:13px">FIB-4 unavailable &mdash; could not load labs. ' +
            '<a href="#" id="fib4-retry" style="color:#009384;font-weight:600">Retry</a></div>');
        jq("#fib4-retry").on("click", function(e){ e.preventDefault(); loadLabsAndRender(); });
    });
    }

    // Load GP overrides first (falls back to defaults on any failure), then render.
    jq.getJSON(base + "/systemsetting?q=mashmasld&v=full")
      .done(applyGpOverrides)
      .always(loadLabsAndRender);
});
</script>