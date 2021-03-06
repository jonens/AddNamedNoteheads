//=============================================================================
//  AddNoteNameNoteHeads v. 1.1
//
//  Copyright (C) 2015 Jon Ensminger
//
//    Parts of code based on shape_notes plugin by Nicolas Froment Copyright (C) //    2015
//    Changes notehead to alphabetic or sol-fa named noteheads
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//=============================================================================

import QtQuick 2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.1
import QtQuick.Controls.Styles 1.3
import MuseScore 1.0

MuseScore {
      version:  "1.0"
      description: qsTr("Replaces noteheads with notename noteheads - StaffText     font: Bravura size: 19")
      menuPath: "Plugins.Notes." + qsTr("Add Named Noteheads")

      property var keySig : 0
      property var majorKey : true
      property var keySigs : []
      property var wholeIndex : 0
      property var halfIndex : 1
      property var quarterIndex : 2
      property var useAlpha : true
      property var useSolfa : false
      property var moveableDo : false
      property var useTi : true
      property var code : 0
      property var nhText : ""
      property var noteHeadColor : "#000000"
      property var bgColor : "#ffffff"
      property var nhType : 0
      property var bgType : 1
      property var noteHead
      property var yOffset : 2.1
      property var userWholeXOffset : 0.0
      property var onStaffVisible : false
      property var offStaffVisible : true

      //Whole / Half / Quarter -- no ##s or bbs -- F C G D A E B
      property var alphaCodesWhole : [0xE177,0xE16E,0xE17A,0xE171,0xE168,0xE174,0xE16B,
                                      0xE178,0xE16F,0xE17B,0xE172,0xE169,0xE175,0xE16C,
                                      0xE179,0xE16F,0xE17C,0xE173,0xE170,0xE176,0xE16D]
      property var alphaCodesHalf : [0xE18E,0xE185,0xE191,0xE188,0xE17F,0xE18B,0xE182,
                                      0xE18F,0xE186,0xE192,0xE189,0xE180,0xE18C,0xE183,
                                      0xE190,0xE187,0xE193,0xE18A,0xE181,0xE18D,0xE184]
     property var alphaCodesQuarter : [0xE1A5,0xE19C,0xE1A8,0xE19F,0xE196,0xE1A2,0xE199,
                                        0xE1A6,0xE19D,0xE1A9,0xE1A0,0xE197,0xE1A3,0xE19A,
                                        0xE1A7,0xE19E,0xE1AA,0xE1A1,0xE198,0xE1A4,0xE19B]

      // no #s or bs for solfa noteheads
      property var solfaCodesWhole :  [0xE153,0xE150,0xE154,0xE151,0xE155,0xE152,0xE156,
                                      0xE153,0xE150,0xE154,0xE151,0xE155,0xE152,0xE156,
                                      0xE153,0xE150,0xE154,0xE151,0xE155,0xE152,0xE156]
      property var solfaCodesHalf :  [0xE15B,0xE158,0xE15C,0xE159,0xE15D,0xE15A,0xE15E,
                                      0xE15B,0xE158,0xE15C,0xE159,0xE15D,0xE15A,0xE15E,
                                      0xE15B,0xE158,0xE15C,0xE159,0xE15D,0xE15A,0xE15E]
      property var solfaCodesQuarter :  [0xE163,0xE160,0xE164,0xE161,0xE165,0xE162,0xE166,
                                        0xE163,0xE160,0xE164,0xE161,0xE165,0xE162,0xE166,
                                        0xE163,0xE160,0xE164,0xE161,0xE165,0xE162,0xE166]

      property var doOffsets : [0,4,1,5,2,6,3,0,4,1,5,2,6,3,0]

      // Apply the given function to all notes in selection
      // or, if nothing is selected, in the entire score

      function applyToNotesInSelection(func) {
          var cursor = curScore.newCursor();
          cursor.rewind(1);
          var startStaff;
          var endStaff;
          var endTick;
          var fullScore = false;

          if (!cursor.segment) { // no selection
              fullScore = true;
              startStaff = 0; // start with 1st staff
              endStaff = curScore.nstaves - 1; // and end with last
          } else {
              startStaff = cursor.staffIdx;
              cursor.rewind(2);
              if (cursor.tick == 0) {
                  // this happens when the selection includes
                  // the last measure of the score.
                  // rewind(2) goes behind the last segment (where
                  // there's none) and sets tick=0
                  endTick = curScore.lastSegment.tick + 1;
              } else {
                  endTick = cursor.tick;
              }
              endStaff = cursor.staffIdx;
          }
          console.log(startStaff + " - " + endStaff + " - " + endTick)
          for (var staff = startStaff; staff <= endStaff; staff++) {
              for (var voice = 0; voice < 4; voice++) {
                  cursor.rewind(1); // sets voice to 0
                  cursor.voice = voice; //voice has to be set after goTo
                  cursor.staffIdx = staff;
                  if (fullScore)
                      cursor.rewind(0) // if no selection, beginning of score
                  while (cursor.segment && (fullScore || cursor.tick < endTick)) {
                      keySig = cursor.keySignature;
                      if (cursor.element && cursor.element.type == Element.CHORD) {
                          var chord = cursor.element;
                          var notes = chord.notes;
                          for (var i = 0; i < notes.length; i++) {
                              var note = notes[i];
                              if (note)  func(note, cursor, chord.duration);
                          }
                      }
                      cursor.next();
                  }
              }
          }
      }

      function createNamedNotehead(note, cursor, duration) {
          if (note.type == Element.NOTE) {
              var durIndex;
              var code = "";
              var codeIndex = note.tpc - 6;
              var wholeXOffset = 0;
              if (codeIndex < 0) {  // if bb
                  codeIndex += 14;  // use natural
              }
              else if (note.tpc > 26) { // if ##
                  codeIndex -= 14;      // use natural
              }
              if (duration >= 1920) {
                  durIndex = wholeIndex;
                  wholeXOffset = userWholeXOffset;
              }
              else if (duration >= 960) {
                  durIndex = halfIndex;
                  wholeXOffset = 0;
              }
              else {
                  durIndex = quarterIndex;
                  wholeXOffset = 0;
              }
              if (useAlpha) {
                  switch (durIndex) {
                      case wholeIndex:
                        code = alphaCodesWhole[codeIndex];
                        break;
                      case halfIndex:
                        code = alphaCodesHalf[codeIndex];
                        break;
                      case quarterIndex:
                        code = alphaCodesQuarter[codeIndex];
                        break;
                      default:
                        break;
                  }

              }
              else if (useSolfa) {
                  if (moveableDo) {
                      if (majorKey) codeIndex = note.tpc - 6 - keySig;
                      else codeIndex = note.tpc - 6 - (keySig + 3);
                  }
                  if (codeIndex < 0) {
                      codeIndex += 14;
                  }
                  else if (codeIndex > 26) {
                      codeIndex -= 14;
                  }
                  switch (durIndex) {
                      case wholeIndex:
                        code = solfaCodesWhole[codeIndex];
                        if (!useTi && codeIndex % 7 == 6) {
                            code = 0xE157;
                        }
                        break;
                      case halfIndex:
                        code = solfaCodesHalf[codeIndex];
                        if (!useTi && codeIndex % 7 == 6) {
                            code = 0xE15F;
                        }
                        break;
                      case quarterIndex:
                        code = solfaCodesQuarter[codeIndex];
                        if (!useTi && codeIndex % 7 == 6) {
                            code = 0xE167;
                        }
                        break;
                      default:
                        break;
                  }
              }
              nhText = String.fromCharCode(code);
              noteHead = newElement(Element.STAFF_TEXT);
              noteHead.text  = "<font size=\"24\"/><font face=\"bravura text\"/>"+nhText;
              noteHead.userOff = Qt.point(0,0);
              noteHead.pos = Qt.point(note.pos.x + wholeXOffset, note.pos.y + yOffset);
              noteHead.color = noteHeadColor;
              var visible;
              if (note.line < 10 && note.line > -2) {
                  //note.visible = onStaffVisible;
                  visible = onStaffVisible;
              }
              else {
                  //note.visible = offStaffVisible;
                  visible = offStaffVisible;
              }
              note.visible = visible;
              note.color = bgColor;
              cursor.add(noteHead);
          }
      }

      ExclusiveGroup { id : exclusiveGroup }
      ExclusiveGroup { id : tiExclusiveGroup }
      ExclusiveGroup { id : modeExclusiveGroup }
      Dialog {
          id : selectDialog
          title : "Notehead Options"
          width: 400
          GridLayout {
              id : grid
              columns : 3
              Text {
                  id : nhOptionsText
                  text : qsTr("<b/>NoteHead Options")
                  Layout.columnSpan : 3
              }
              CheckBox {
                  id : alphaCheckBox
                  checked : true
                  exclusiveGroup : exclusiveGroup
                  text : qsTr("Alpha Noteheads")
                  onClicked : {
                      moveDoCheckBox.checked = false;
                      majorCheckBox.checked = false;
                      minorCheckBox.checked = false;
                      tiCheckBox.checked = false;
                      siCheckBox.checked = false;
                  }
              }
              Text {
                  id : spText2
                  text : ""
                  Layout.columnSpan : 2
              }
              CheckBox {
                  id : solfaCheckBox
                  checked : false
                  exclusiveGroup : exclusiveGroup
                  text : qsTr("Sol-Fa Noteheads")
                  Layout.columnSpan : 3
                  onClicked : {
                      moveDoCheckBox.checked = false;
                      majorCheckBox.checked = true;
                      minorCheckBox.checked = false;
                      tiCheckBox.checked = true;
                      siCheckBox.checked = false;
                  }
              }
              CheckBox {
                  id : moveDoCheckBox
                  checked : false
                  text : qsTr("Movable Do")
              }
              CheckBox {
                  id : majorCheckBox
                  checked : false
                  exclusiveGroup : modeExclusiveGroup
                  text : qsTr("Major Key")
              }
              CheckBox {
                  id : minorCheckBox
                  checked : false
                  exclusiveGroup : modeExclusiveGroup
                  text : qsTr("Minor Key")
              }
              CheckBox {
                  id : tiCheckBox
                  checked : false
                  exclusiveGroup : tiExclusiveGroup
                  text : qsTr("Ti")
              }
              CheckBox {
                  id : siCheckBox
                  checked : false
                  exclusiveGroup : tiExclusiveGroup
                  text : qsTr("Si")
                  Layout.columnSpan : 2
              }
              Text {
                  id : colOptionsText
                  text : qsTr("<b/>Color Options")
                  Layout.columnSpan : 3
              }
              Text {
                  id : nhColorText
                  text : qsTr("Notehead Color")
              }
              Rectangle {
                  id : nhColorRect;
                  width : 80
                  height : 50
                  color : noteHeadColor
                  Layout.columnSpan : 2
                  MouseArea {
                      anchors.fill: parent
                      onClicked: {
                        nhColorDialog.open();
                      }
                  }
              }
              Text {
                  id : bgColorText
                  text : qsTr("Note Background Color")
              }
              Rectangle {
                  id : bgColorRect;
                  width : 80
                  height : 50
                  color : bgColor
                  Layout.columnSpan : 2
                  MouseArea {
                      anchors.fill: parent
                      onClicked: {
                        bgColorDialog.open();
                      }
                  }
              }
              Text {
                  id : layoutOptionsText
                  Layout.columnSpan : 3
                  text : qsTr("<b/>Layout Options")
              }
              Text {
                  id : yOffsetText
                  text : qsTr("Vertical Offset")
              }
              SpinBox {
                  id : yOffsetSpinBox
                  decimals : 2
                  maximumValue : 6.00
                  minimumValue : -6.00
                  stepSize: 0.02
                  value : yOffset
                  Layout.columnSpan : 2
                  style: SpinBoxStyle{
                      background: Rectangle {
                      implicitWidth: 80
                      implicitHeight: 25
                      border.color: "gray"
                      color : "#eeeeee"
                      radius: 2
                      }
                  }
                  onEditingFinished : { yOffset = value; console.log("yOffset " + yOffset);}
              }
              Text {
                  id : wnOffsetText
                  text : qsTr("Whole Note X Offset")
              }
              SpinBox {
                  id : wnOffsetSpinBox
                  decimals : 2
                  maximumValue : 3.00
                  minimumValue : -3.00
                  stepSize: 0.02
                  value : userWholeXOffset
                  Layout.columnSpan : 2
                  style: SpinBoxStyle{
                      background: Rectangle {
                      implicitWidth: 80
                      implicitHeight: 25
                      border.color: "gray"
                      color : "#eeeeee"
                      radius: 2
                      }
                  }
                  onEditingFinished : { userWholeXOffset = value;console.log("wXOffset " + userWholeXOffset);}
              }
              Text {
                  id : hiddenOptionsText
                  text : qsTr("<b/>Background Note Hide Options")
                  Layout.columnSpan : 3
              }
              CheckBox {
                  id : onHideCheckBox
                  checked : true
                  text : qsTr("Hide On Staff")
                  onClicked : { setHidden() }
              }
              CheckBox {
                  id : offHideCheckBox
                  checked : false
                  text : qsTr("Hide Off Staff")
                  onClicked : { setHidden() }
              }
          }
          standardButtons: StandardButton.Cancel | StandardButton.Ok
          onAccepted: {
                applyFunction();
          }
          onRejected : Qt.quit()
      }

      Dialog {
          id : readmeDialog
          title : qsTr("Instructions")
          width : 470
          Text {
              id : readmeText
              text : qsTr("<b>Description:</b>  Places a named Notehead on existing notes in a selection,<br/>or the whole score if no selection.<br/><br/>
              <b>User Options:</b><br/>
              <ul>
              <li>Alpha- or Solfa- Notehead type
              <li>Major or Minor key (for Solfa)
              <li>Ti or Si (for Solfa)
              <li>Fixed or Movable Do (for Solfa)
              <li>Notehead color
              <li>Background note color
              <li>Notehead vertical offset (for fine tuning)
              <li>Whole note horizontal offset (for fine tuning)
              <li>Hide/unhide background notes on staff
              <li>Hide/unhide background notes off staff (leger lines)
              </ul>
              <br/>
              Use Edit\/Undo or Select/All similar elements in MuseScore to<br/>remove named Noteheads.
              <br/><br/>
              Some noteheads might require manual repositioning after the plugin<br/>is run.  If all noteheads are slightly misaligned vertically, try removing<br/>all noteheads (Edit/Undo or Select/All similar elements/Cut), adjust<br/>the Notehead vertical offset in the plugin's Options dialog, then run<br/>the plugin again. Lower numeric offset values move the noteheads<br/>up, and higher numeric values move the noteheads down.
              <br/><br/>
              <b>Please Note:</b> Named Noteheads are Staff Text elements, and will not<br/>change position or name if the underlying note pitches change.<br/>To change note names/positions, use the Undo command and<br/>re-run the plugin after making the changes to the underlying notes.")
          }
          standardButtons: StandardButton.Cancel | StandardButton.Ok
          onAccepted : selectDialog.open();
          onRejected : Qt.quit();
      }

      ColorDialog {
          id: nhColorDialog
          title: qsTr("Notehead Color")
          onAccepted : changeColor(nhType)
          onRejected: Qt.quit();
      }

      ColorDialog {
          id: bgColorDialog
          title: qsTr("Note Background Color")
          onAccepted : changeColor(bgType)
          onRejected: Qt.quit();
      }

      function changeColor(type) {
          if (type == nhType) {
              nhColorRect.color = nhColorDialog.color;
              noteHeadColor = nhColorDialog.color;
          }
          if (type == bgType) {
              bgColorRect.color = bgColorDialog.color;
              bgColor = bgColorDialog.color;
          }
      }

      function setHidden() {
          onStaffVisible = !onHideCheckBox.checked;
          offStaffVisible = !offHideCheckBox.checked;

      }

      function applyFunction() {
          yOffset = yOffsetSpinBox.value;
          userWholeXOffset = wnOffsetSpinBox.value;
          if (majorCheckBox.checked) {
              majorKey = true;
              console.log("majorChecked " + majorCheckBox.checked + " majorKey " + majorKey);
          }
          else if (minorCheckBox.checked) {
              majorKey = false;
              console.log("minorChecked " + minorCheckBox.checked + " majorKey " + majorKey);
          }
          if (alphaCheckBox.checked) {
              useAlpha = true;
              useSolfa = false;
              tiCheckBox.checked = false;
              siCheckBox.checked = false;
          }
          else {
              useSolfa = true;
              useAlpha = false;
              if (moveDoCheckBox.checked){
                  moveableDo = true;
              }
              else {
                  moveableDo = false;
              }
              if (tiCheckBox.checked){
                  useTi = true;
              }
              else {
                  useTi = false;
              }
          }
          curScore.startCmd();
          applyToNotesInSelection(createNamedNotehead);
          curScore.endCmd();
            Qt.quit();
      }

      onRun: {
          if (typeof curScore === 'undefined')
              Qt.quit();
          readmeDialog.open();
      }
}
