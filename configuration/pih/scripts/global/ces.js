/**
 * Ensures that if the box is ticked to remove a patient from a program,
 * then the user must have also provided an outcome.
 */
function setUpProgramExitStatusValidation(requiredMsg) {
  const programs = [
    "asthma",
    "diabetes",
    "epilepsy",
    "maternal",
    "mental",
    "hypertension",
  ];
  beforeSubmit.push(function () {
    let noErrors = true;
    for (let program of programs) {
      if (
        getValue(program + "-exit-checkbox.value") &&
        !getValue(program + "-exit-status.value")
      ) {
        getField(program + "-exit-status.error")
          .html(requiredMsg)
          .show();
        noErrors = false;
      }
    }
    return noErrors;
  });
}

/**
 * Make the Cholesterol section show when Diabetes or Hypertension is checked
 *
 * Requires:
 *   - Element with ID 'diabetes-enroll' containing a checkbox input
 *   - Element with ID 'htn-enroll' containing a checkbox input
 *   - Element with ID 'diabetes'
 *   - Element with ID 'cholesterol'
 */
function setUpCholesterolSection() {
  var dmCheckbox = jq("#diabetes-enroll > input[type='checkbox']")[0];
  var htnCheckbox = jq("#htn-enroll > input[type='checkbox']")[0];
  var dmSection = jq("#diabetes");
  var cholSection = jq("#cholesterol");

  var updateCholSectionVisibility = function () {
    if (dmCheckbox.checked | htnCheckbox.checked) {
      cholSection.show();
    } else {
      cholSection.hide();
    }
  };
  var updateDmSectionVisibility = function () {
    if (dmCheckbox.checked) {
      dmSection.show();
    } else {
      dmSection.hide();
    }
  };
  jq(dmCheckbox).change(function () {
    updateDmSectionVisibility();
    updateCholSectionVisibility();
  });
  jq(htnCheckbox).change(function () {
    updateCholSectionVisibility();
  });
  updateDmSectionVisibility();
  updateCholSectionVisibility();
}

/**
 * Requires:
 *   - Obs with ID 'epi-baseline'
 *   - Obs with ID 'seizure-num'
 *   - Element with ID 'epi-baseline-last-obs'
 *   - Element with ID 'seizure-percent-reduction-container'
 *   - Element with ID 'seizure-percent-reduction'
 */
function setUpEpilepsySection() {
  getField("epi-baseline.value").change(updatePercentReduction);
  getField("seizure-num.value").change(updatePercentReduction);
  updatePercentReduction();
  initializeBaseline();

  function updatePercentReduction() {
    var baseline = parseInt(htmlForm.getValueIfLegal("epi-baseline.value"));
    if (isNaN(baseline)) {
      baseline = parseInt(
        document.getElementById("epi-baseline-last-obs").innerHTML.trim()
      );
    }
    var current = parseInt(htmlForm.getValueIfLegal("seizure-num.value"));
    var container = jq("#seizure-percent-reduction-container");
    if (!(isNaN(current) || isNaN(baseline))) {
      var result = calculatePercentReduction(baseline, current).toString();
      document.getElementById("seizure-percent-reduction").innerHTML = result;
      container.show();
    } else {
      container.hide();
    }
  }

  function calculatePercentReduction(baseline, current) {
    return Math.round(((baseline - current) / baseline) * 100);
  }

  function initializeBaseline() {
    var baseline = parseInt(
      document.getElementById("epi-baseline-last-obs").innerHTML.trim()
    );
    var baselineInput = jq("#epi-baseline-input").hide();
    var baselineButton = jq("#change-epi-baseline-button").show();
    if (isNaN(baseline)) {
      baselineButton.hide();
      baselineInput.show();
    } else {
      baselineInput.hide();
      baselineButton.show();
    }
    jq("#change-epi-baseline-button").click(showChangeBaseline);
  }

  function showChangeBaseline() {
    jq("#epi-baseline-input").show();
  }
}

/** This is almost the same as the `setUpEdd` function in
 * `openmrs-config-pihemr/.../mch.js`. The only difference is that it supports
 * calculating EDD & gestational age from the last entered LMP.
 * Requirements are the same as for `setUpEdd`, but with the addition of
 *   - An element with ID 'lmp-existing'
 * And with no obs element with ID 'edd'.
 */
function setUpMaternalSection(currentEncounterDate, msgWeeks) {
  function getLastPeriodDate() {
    var datepickerValue = getField("lastPeriodDate.value").datepicker(
      "getDate"
    );
    if (datepickerValue !== null) {
      return datepickerValue;
    }
    var dateText = jq("#lmp-existing").text().trim();
    if (dateText !== null && dateText !== "") {
      // We're going to use an absolutely evil hack to try and get a date object
      // from the LMP string we have, without access to Moment.js or anything
      // nice like that. We'll coerce the string into the input box, get the
      // date object out, and reset the box.
      // replace the slashes with spaces
      var dateTextFormatted = dateText.replace(/\//g, " ");
      // get the date object
      getField("lastPeriodDate.value")
        .datepicker("setDate", dateTextFormatted)
        .val();
      var dateValue = new Date(
        getField("lastPeriodDate.value").datepicker("getDate")
      );
      // reset the input box
      getField("lastPeriodDate.value").datepicker("setDate", datepickerValue);
      return dateValue;
    }
    return null;
  }

  function updateEdd() {
    const lastPeriodDateValue = getLastPeriodDate();
    if (lastPeriodDateValue) {
      const lastPeriodDate = new Date(lastPeriodDateValue);
      const today = currentEncounterDate
        ? new Date(+currentEncounterDate)
        : new Date();
      const gestAgeMs = today.getTime() - lastPeriodDate.getTime();
      const gestAgeDays = Math.floor(gestAgeMs / (1000 * 3600 * 24));
      const gestAgeWeeks = Math.floor(gestAgeDays / 7);
      const gestAgeRemainderDays = gestAgeDays % 7;
      const locale = window.sessionContext.locale || navigator.language;
      const edd = new Date(
        lastPeriodDate.getTime() + 1000 * 60 * 60 * 24 * 280
      );
      jq("#calculated-edd-and-gestational").show();
      jq("#calculated-edd").text(
        Intl.DateTimeFormat(locale, { dateStyle: "full" }).format(edd)
      );
      const gestAgeText =
        gestAgeWeeks +
        " " +
        (gestAgeRemainderDays ? gestAgeRemainderDays + "/7 " : " ") +
        msgWeeks;
      jq("#calculated-gestational-age-value").text(gestAgeText);
    } else {
      jq("#calculated-edd-and-gestational").hide();
    }
  }

  jq("#calculated-edd-and-gestational").hide();

  jq("#lastPeriodDate input[type='hidden']").change(function () {
    updateEdd();
  });

  updateEdd();
}

/**
 * Requires:
 *   - Elements with the following classes:
 *     - medication-name
 *     - dose
 *     - dose-unit
 *     - frequency
 *     - duration
 *     - duration-unit
 *     - medication-instructions
 *   - An element with class 'field-error'
 */
function setUpPlanSection(
  noMedicationMsg,
  noDoseUnitsMsg,
  noDoseMsg,
  noDurationUnitsMsg,
  noDurationMsg
) {
  htmlForm.getBeforeValidation().push(function () {
    var valid = true;

    jq("fieldset.medication").each(function () {
      // clear out any existing error messages
      jq(this).find(".field-error").first().html("");

      var medication = jq(this).find(".medication-name input").val();
      var dose = jq(this).find(".dose input").val();
      var doseUnits = jq(this).find(".dose-unit select").val();
      var frequency = jq(this).find(".frequency select").val();
      var duration = jq(this).find(".duration input").val();
      var durationUnits = jq(this).find(".duration-unit select").val();
      var instructions = jq(this).find(".medication-instructions input").val();

      if (
        !medication &&
        (dose ||
          doseUnits ||
          frequency ||
          duration ||
          durationUnits ||
          instructions)
      ) {
        valid = false;
        jq(this).find(".field-error").first().append(noMedicationMsg).show();
      }

      if (dose && !doseUnits) {
        valid = false;
        jq(this).find(".field-error").first().append(noDoseUnitsMsg).show();
      }

      if (!dose && doseUnits) {
        valid = false;
        jq(this).find(".field-error").first().append(noDoseMsg).show();
      }

      if (duration && !durationUnits) {
        valid = false;
        jq(this).find(".field-error").first().append(noDurationUnitsMsg).show();
      }

      if (!duration && durationUnits) {
        valid = false;
        jq(this).find(".field-error").first().append(noDurationMsg).show();
      }
    });

    return valid;
  });
}

/**
 * This is a very ugly hack. It creates a new document in a new window,
 * populates that document with things from the current form, and prints it.
 *
 * It is very fragile, both with respect to the form and to browser standards.
 */
function printPrescription() {
  const w = window.open(
    "",
    "",
    "left=0,top=0,width=800,height=900,toolbar=0,scrollbars=0,status=0"
  );
  const styleNodes = document.getElementsByTagName("style");
  for (var i = 0; i < styleNodes.length; i++) {
    const styleNode = styleNodes[i];
    w.document.write("<style>" + styleNode.innerHTML + "</style>");
  }
  w.document.write("<body>");
  const dateOptions = { year: "numeric", month: "short", day: "numeric" };
  const dateString = new Date().toLocaleDateString("es", dateOptions);
  w.document.write('<div class="date">' + dateString + "</div>");
  const logos = jq(document.getElementById("logos")).clone();
  logos.removeClass("hidden");
  logos.appendTo(w.document.body);
  w.document.write("<p>");
  const givenName = jq(
    document.getElementsByClassName("zl-givenName")[0]
  ).clone();
  givenName.text(givenName.text() + " ");
  w.document.write(givenName.html());
  const familyName = jq(
    document.getElementsByClassName("zl-familyName")[0]
  ).clone();
  familyName.text(familyName.text().match(/[^,]*/));
  w.document.write(familyName.html());
  w.document.write("</p>");
  w.document.write("<p>");
  const gender = jq(
    document.getElementsByClassName("gender-age")[0].children[0]
  ).clone();
  gender.text(gender.text().match(/^\w+/) + ", ");
  w.document.write(gender.html());
  const age = jq(
    document.getElementsByClassName("gender-age")[0].children[1]
  ).clone();
  age.text(age.text().match(/\d+/));
  w.document.write(age.html());
  w.document.write("</p>");
  w.document.write("<p>");
  w.document.write("Diagnosticos: ");
  w.document.write(
    jq.map(jq(".diagnosis .matched-name"), (d) => d.textContent).join(", ")
  );
  w.document.write("</p>");
  jq(document.getElementById("drug-orders")).clone().appendTo(w.document.body);
  const medNames = jq(w.document).find(".medication-name");
  for (let i = 0; i < medNames.length; i++) {
    const medP = jq(medNames[i]).parent();
    medP.css("display", "inline");
  }
  jq(document.getElementById("clinical-management-plan"))
    .clone()
    .appendTo(w.document.body);
  jq(document.getElementById("contact-info-inline"))
    .clone()
    .appendTo(w.document.body);
  w.document.write("<p>");
  w.document.write("Próxima cita: ");
  w.document.write(jq("#apptDate").find(".hasDatepicker").val());
  w.document.write("</p>");
  w.document.write("</body>");
  w.document.close();
  w.setTimeout(() => {
    w.focus();
    w.print();
    w.close();
  }, 1000);
}

function sectionDisplayDx() {
  var changeRadioYes = jq("#DxChange > input[type='radio']")[0];
  var changeRadioNo = jq("#DxChange > input[type='radio']")[1];
  var sectionDx = jq("#OptionChangeDx");

  var sectionVisibilityDx = function () {
    if (changeRadioYes.checked) {
      sectionDx.show();
    }

    if (changeRadioNo.checked) {
      sectionDx.hide();
    }
  };

  jq(changeRadioYes).change(function () {
    sectionVisibilityDx();
  });

  jq(changeRadioNo).change(function () {
    sectionVisibilityDx();
  });
}

function alertCuestion9PHQ() {
  let selectCuestion9 = jq("#cuestion9 select");
  jq(selectCuestion9).change(function () {
    if (
      jq(this).find("option:selected").text() == "Nunca" ||
      jq(this).val() == ""
    ) {
      jq("#Alert").text("");
    } else {
      jq("#Alert").text(
        "No olvides hacer el plan de seguridad con este paciente. Además, en caso de que tenga factores de riesgo (intentos previos, poca red de apoyo, uso de sustancias, etc) y que tenga un plan más desarrollado y/o acceso al método no olvides que deberá romperse la confidencialidad y pedir a un familiar que no deje solo (a) al/la paciente por las siguientes 24 hrs."
      );
    }
  });
}

function setupPHQ() {
  jq("#CuestionsPHQ9")
    .find("select")
    .change(function () {
      actualizarPHQ9();
    });
}

function actualizarPHQ9() {
  const valueByAnswerConcept = {
    Nunca: 0,
    "Pocos días": 1,
    "Más de la mitad de los días": 2,
    "Casi todos los días": 3,
  };

  const total = sum(
    jq("#CuestionsPHQ9")
      .find("select")
      .toArray()
      .map(
        (select) =>
          valueByAnswerConcept[jq(select).find("option:selected").text()]
      )
      .filter((valor) => valor != undefined)
  );

  jq("#ResultPHQ9 input").val(total);
}

function setupGAD() {
  jq("#CuestionsGAD7")
    .find("select")
    .change(function () {
      actualizarGAD7();
    });
}

function actualizarGAD7() {
  const valueByAnswerConcept = {
    Nunca: 0,
    "Pocos días": 1,
    "Más de la mitad de los días": 2,
    "Casi todos los días": 3,
  };

  const total = sum(
    jq("#CuestionsGAD7")
      .find("select")
      .toArray()
      .map(
        (select) =>
          valueByAnswerConcept[jq(select).find("option:selected").text()]
      )
      .filter((valor) => valor != undefined)
  );

  jq("#ResultGAD7 input").val(total);
}

function sum(arr) {
  return arr.reduce((partialSum, a) => partialSum + a, 0);
}
