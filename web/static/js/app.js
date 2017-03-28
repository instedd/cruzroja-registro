// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html";

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

import { Users } from "./users";
import { Branches } from "./branches";
import { Registration } from "./registration";

export var App = {
  run: function() {
    $('select').material_select();

    $('.datepicker:not([disabled])').pickadate({
      selectMonths: false,
      selectYears: 110,
      today: null,
      clear: null,
      close: "Cerrar",
      monthsFull: ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'],
      monthsShort: ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'],
      weekdaysFull: ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'],
      weekdaysShort: ['Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'],
      weekdaysLetter: [ 'D', 'L', 'M', 'M', 'J', 'V', 'S' ],
      format: 'dd/mm/yyyy',
      max: new Date(),
      hiddenName: true, // send only the value formatted for the server, not the human readable one
      formatSubmit: 'yyyy-mm-dd'
    });

    // initialize all modules
    Users.init();
    Branches.init();
    Registration.init();
  }
};
