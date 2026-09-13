// any CSS you require will output into a single css file (app.css in this case)
require('../css/app.css');

const $ = require('jquery');

global.$ = global.jQuery = $;

require('select2');
$('select').select2();

let $contactButton = $('#contactButton');
$contactButton.click((e) => {
    e.preventDefault();
    $('#contactForm').slideDown();
    $contactButton.slideUp();
});