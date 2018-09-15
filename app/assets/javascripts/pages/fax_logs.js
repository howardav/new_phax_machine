/////////////////////////////////////////////////////////////////////////////////
//  SEE CREATE.JS.ERB IN THE FAX_LOGS VIEW FOLDER FOR ADDITIONAL JS FUNCTIONS  //
/////////////////////////////////////////////////////////////////////////////////

phaxMachine.pages['fax-logs'] = {

	render: function() {

		organizationOptions = $("#org-select option"),
		userOptions = $("#user-select option"),
		faxNumberOptions = $("#fax-select option"),
		currentPageNumber = 1;
		backButtonText = '<';
		forwardButtonText = '>';
		endButtonText = '>>';
		beginningButtonText = '<<';

		$("#load-icon").hide();

		$("#filter-button").on('click', function(event) {
			$("tbody").empty();
			$("#pagination-ul").empty();
			$("#load-icon").show();
		});

	  $('.datepicker-inline').flatpickr({
    	enableTime: true,
    	dateFormat: 'Y-m-d h:iK',
    	altInput: true,
    	altFormat: 'm-d-Y h:i K',
	    maxDate: new Date(),
	    autoclose: true
		});

		$("#org-select").change((event) => {
			event.stopPropagation();

			let organizationClass = $("#org-select option:selected").attr('class');
			let $faxSelect = $("#fax-select");
			let $orgSelect = $("#org-select");

			$faxSelect.empty();

			if (organizationClass === "all-org") {
				$orgSelect.empty();
				restoreSelectTag(organizationOptions, $orgSelect);
				restoreSelectTag(faxNumberOptions, $faxSelect);
			} else {
			 	$faxSelect.append(`<option class="all-linked" name="fax_log[fax_number]" value="all-linked">All Linked Numbers</option>`);
				createSelectTagMultipleConditionals(faxNumberOptions, $faxSelect, [organizationClass, 'all-fax']);
			 	$("#fax-select option").first().prop('selected', 'selected');
			}
		});

		$("#fax-select").change((event) => {
			event.stopPropagation();

			let organizationClass = $("#org-select option:selected").attr('class');
			let faxNumberClass = $("#fax-select option:selected").attr('class');
			let userClass = $("#user-select option:selected").attr('class');
			let $userSelect = $("#user-select");
			let $orgSelect = $("#org-select");

			if (userClass === 'all-user') {
				let = desiredOptionId = $("#user-select option:selected").attr('id');
				$($userSelect).empty();
				$userSelect.append(`<option class="all-linked" name="fax_log[user]" value="all-linked">All Linked Users</option>`);
				createSelectTagMultipleConditionals(userOptions, $userSelect, [faxNumberClass, 'all-user']);
				$("#user-select option").first().prop('selected', 'selected');
			} else if (userClass === 'all-linked' || faxNumberClass === 'all-linked') {
				// do nothing
			} else if (faxNumberClass === 'all-fax') {
				$($orgSelect).empty();
				restoreSelectTag(organizationOptions, $orgSelect);
			} else if (organizationClass === 'all-org' || faxNumberClass !== organizationClass) {
				$($orgSelect).empty();
				createSelectTagMultipleConditionals(organizationOptions, $orgSelect, [faxNumberClass, 'all-org']);
				$("#org-select option").first().prop('selected', 'selected');
			}
		});

		$("#user-select").change((event) => {
			event.stopPropagation();

			let userClass = $("#user-select option:selected").attr('class');
			let $userSelect = $("#user-select");
			let $faxSelect = $("#fax-select");

			if (userClass === "all-user") {
				$faxSelect.empty();
				$($userSelect).empty();
				restoreSelectTag(faxNumberOptions, $faxSelect);
				restoreSelectTag(userOptions, $userSelect);
			}
		});
		//This "tr" click function is the same as addFileIconClick(), but it's here for the initial page load
		$("tr").on('click', $(".fa-download"), (event) => {
			event.preventDefault();
			faxID = {
				'fax': {
					'id': ''
				}
			}
			faxID['fax']['id'] = parseInt($(event.target).closest("tr").attr("id"));

			$.ajax({
				type: "POST",
				url: "/download",
				data: JSON.stringify(faxID),
				contentType: 'application/json',
			});

		});
		changeStatusColor();
	}
};

function buildTableRows(faxData, pageNumberDisplay) {
	let sentIcon = `<i style="color:green" class="fa fa-fw fa-arrow-circle-right" aria-hidden="true"></i>`;
	let receivedIcon = `<i style="color:darkblue" class="fa fa-fw fa-arrow-circle-left" aria-hidden="true"></i>`;

	Object.keys(faxData).forEach((faxDatum) => {
		if (faxData[faxDatum]['page'] === pageNumberDisplay) {

			if (faxData[faxDatum].organization === undefined) { faxData[faxDatum].organization = "N/A"; };
			if (faxData[faxDatum].sent_by === undefined) { faxData[faxDatum].sent_by = ""; };
			if (faxData[faxDatum].from_number === undefined) { faxData[faxDatum].from_number = "Released Number"; };
			if (faxData[faxDatum].to_number === undefined) { faxData[faxDatum].to_number = "Released Number"; };

			let head = `<tr id="${faxDatum}">
				<td class="text-center"> ${ (faxData[faxDatum].direction === "Sent") ? sentIcon : receivedIcon } </td>`;
			// Admin has 8 <th>, Manager has 7 <th>, User has only 6. These if blocks add/remove data for these permission levels
				if ($('#fax-log-table th').length === 8) { head = head.concat('', `<td class="text-center">${faxData[faxDatum].organization}</td>`); }
				if ($('#fax-log-table th').length > 6) { head = head.concat('', `<td class="text-center">${faxData[faxDatum].sent_by}</td>`); }

			head = head.concat('', `
				<td class="text-center">${faxData[faxDatum].from_number}</td>
				<td class="text-center">${faxData[faxDatum].to_number}</td>
				<td class="status">${faxData[faxDatum].status}</td>
				<td class="text-center">${faxData[faxDatum].created_at}</td>
				<td class="text-center"><i class="fa fa-fw fa-download" aria-hidden="true"></i></td>
			</tr>
			`);
			$("tbody").prepend(head);
		}
	});
	changeStatusColor();
	addFileIconClick();
};

function changeStatusColor() {
	$.each($('.status'), function() { // $(this) is the entire <td> tag within the $.each()
		switch($(this).text()) {
			case 'Success': // These statuses are capitalized unlike the normal API response b/c Ruby's 'titleize() is used in FaxLog model'
				$(this).prepend(`
					<span style='color:limegreen'>&nbsp;<i style='font-size:10px' class="fa fa-fw fa-circle"></i>&nbsp;</span>
				`);
				break;
			case 'Queued':
				$(this).prepend(`
					<span style='color:darkgrey'>&nbsp;<i style='font-size:10px' class="fa fa-fw fa-circle"></i>&nbsp;</span>
				`);
				break;
			case 'Inprogress':
				$(this).text('In Progress');
				$(this).prepend(`
					<span style='color:darkblue'>&nbsp;<i style='font-size:10px' class="fa fa-fw fa-circle"></i>&nbsp;</span>
				`)
				break;
			case 'Failure':
				$(this).prepend(`
					<span style='color:crimson'>&nbsp;<i style='font-size:10px' class="fa fa-fw fa-circle"></i>&nbsp;</span>
				`);
				break;
			case 'Partialsuccess':
				$(this).text('Partial Success')
				$(this).prepend(`
					<span style='color:darkorange'>&nbsp;<i style='font-size:10px' class="fa fa-fw fa-circle"></i>&nbsp;</span>
				`);
				break;
		}
	});
};

function restoreSelectTag(originalTagData, tagBeingRestored) {
	$.each(originalTagData, function() { tagBeingRestored.append($(this)); });
};

function createSelectTagMultipleConditionals(originalTagData, tagBeingRestored, addIfClasses) {
	addIfClasses.forEach((addIfClass) => {
		$.each(originalTagData, function() {
			if ($(this).hasClass(addIfClass)) { tagBeingRestored.append($(this)); }
		});
	});
};

function paginateFaxes(apiResponse) {
	let pageNumber = 0;
	let counter = 1;
	let $pageNumberList = $("#pagination-ul");

	addPreviousSymbol($pageNumberList, currentPageNumber, beginningButtonText);
	addPreviousSymbol($pageNumberList, currentPageNumber, backButtonText);

	let highestPageNumber = addPageNumbersToResponse($pageNumberList, pageNumber, currentPageNumber);

	addNextSymbol($pageNumberList, pageNumber, currentPageNumber, forwardButtonText);
	addNextSymbol($pageNumberList, pageNumber, currentPageNumber, endButtonText);

	if (highestPageNumber > 18) { splitPagination(pageNumber, currentPageNumber, highestPageNumber); }
};

function addPageNumbersToResponse($pageNumberList, pageNumber, currentPageNumber) {
	Object.keys(apiResponse).forEach((key, counter) => {
		if (counter % 20 === 0) { 
			pageNumber += 1;
			addPageNumber($pageNumberList, pageNumber, currentPageNumber);
		}
		apiResponse[key]['page'] = pageNumber;
	});
	return pageNumber;
}

function addPageNumber($pageNumberList, pageNumber, currentPageNumber) {
	if (pageNumber === currentPageNumber) {
		$pageNumberList.append(`<li id="${pageNumber}" class="page-item active"><a class="page-link" href="#">${pageNumber}</a></li>`);
	} else {
		$pageNumberList.append(`<li id="${pageNumber}" class="page-item"><a class="page-link" href="#">${pageNumber}</a></li>`);
	}
};

function addPreviousSymbol($pageNumberList, currentPageNumber, symbolToAdd) {
	if (currentPageNumber === 1) {
		$pageNumberList.append(`<li class="page-item disabled"><a class="page-link" href="#">${symbolToAdd}</a></li>`);
	} else {
		$pageNumberList.append(`<li class="page-item"><a class="page-link" href="#">${symbolToAdd}</a></li>`);
	}
};
// pageNumber is highestPageNumber in split pagination
function addNextSymbol($pageNumberList, pageNumber, currentPageNumber, symbolToAdd) {
	if (pageNumber === currentPageNumber) {
		$pageNumberList.append(`<li class="page-item disabled"><a class="page-link" href="#">${symbolToAdd}</a></li>`);
	} else {
		$pageNumberList.append(`<li class="page-item"><a class="page-link" href="#">${symbolToAdd}</a></li>`);
	}
};

function splitPagination(pageNumber, currentPageNumber, highestPageNumber) {
	let $pageNumberList = $("#pagination-ul");
	let pageNumberArray = $.makeArray($("#pagination-ul li")).slice(2, ($pageNumberList.length - 3));//Remove '<<' and "<" from ends
	let pageNumbersLeft = [];
	let pageNumbersMiddle = [];
	let pageNumbersRight = [];

	let i = 0;
	while (i < 3) {
		pageNumbersLeft.push(pageNumberArray[i]);
		pageNumbersRight.push(pageNumberArray[(highestPageNumber - 1) - i]);
		i++;
	};

	pageNumbersMiddle = constructPaginationMiddle(pageNumbersMiddle, pageNumberArray, currentPageNumber, highestPageNumber)
	pageNumbersRight = pageNumbersRight.sort((a,b) => { return $(a).attr('id') - $(b).attr('id'); });

	$pageNumberList.empty();

	addPreviousSymbol($pageNumberList, currentPageNumber, beginningButtonText);
	addPreviousSymbol($pageNumberList, currentPageNumber, backButtonText);

	pageNumbersLeft.forEach((element) => { addPageNumber($pageNumberList, parseInt($(element).attr('id')), currentPageNumber); });
	$pageNumberList.append(`<li class="page-item-dots force-down-dots">&nbsp&nbsp&nbsp&nbsp...&nbsp&nbsp&nbsp&nbsp</li>`);
	pageNumbersMiddle.forEach((element) => { addPageNumber($pageNumberList, parseInt($(element).attr('id')), currentPageNumber); });
	$pageNumberList.append(`<li class="page-item-dots force-down-dots">&nbsp&nbsp&nbsp&nbsp...&nbsp&nbsp&nbsp&nbsp</li>`);
	pageNumbersRight.forEach((element) => { addPageNumber($pageNumberList, parseInt($(element).attr('id')), currentPageNumber); });

	addNextSymbol($pageNumberList, highestPageNumber, currentPageNumber, forwardButtonText);
	addNextSymbol($pageNumberList, highestPageNumber, currentPageNumber, endButtonText);
};

function constructPaginationMiddle(pageNumbersMiddle, pageNumberArray, currentPageNumber, highestPageNumber) {
	let arrayMiddle = 0;
	if (currentPageNumber > 3 && currentPageNumber <= highestPageNumber - 3) {
		arrayMiddle = currentPageNumber - 1
	} else {
		arrayMiddle = (pageNumberArray.length % 2 === 0) ? (pageNumberArray.length / 2) - 1 : Math.floor(pageNumberArray.length / 2)
	}
	pageNumbersMiddle.push(pageNumberArray[arrayMiddle])

	let j = 1;
	while (j < 4) {
		pageNumbersMiddle.push(pageNumberArray[arrayMiddle + j]);
		pageNumbersMiddle.push(pageNumberArray[arrayMiddle - j]);
		j++;
	};
	return pageNumbersMiddle.sort((a,b) => { return $(a).attr('id') - $(b).attr('id'); });
};

function addFileIconClick() {
	$("tr").on('click', $(".fa-download"), (event) => {
		console.log($(event.target))
		console.log($(event.target).closest("tr"))
		console.log($(event.target).closest("tr").attr("id"))
	});
};