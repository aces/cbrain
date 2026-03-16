//
//  CBRAIN Project
//
//  Copyright (C) 2008-2012
//  The Royal Institution for the Advancement of Learning
//  McGill University
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//

// JS to add indetermitate state to checkboxes with indeterninate style

// indeterminate state on can be set with JS
// all elements with empty value are set as indeterminate
$(".show_table_edit_link").click(
    function () {
        $(".indeterminate").each(
            function () {
                $(this).prop("indeterminate", true);
                $(this).val(""); // checked indeterminate can still passes value
                let prev = $(this).prev();
                let val = prev.val();
                if (val == "disabled") {
                    prev.val("");
                }
            }
        )
    }
);


$(".indeterminate").click(
    function () {
        $(this).val('allowed');
        let prev = $(this).prev();
        prev.val("disabled");
    }
)







