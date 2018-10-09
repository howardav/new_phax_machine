// This code repeatedly adds a new drag/drop file div on top of the previous one that already has a file within it. 
// Each new drag/drop div has a unique ID determined by a fileCounter attribute. The fileCounter attribute never
// decreases. addRemoveFiles() is the 'meat and potatoes' function that drives this process for the most part.

const dragOverColor = '#e0e0e0';
const dragLeaveColor = '#fafafa';
const alertMessage = 'File limit exceeded. A maximum of 20 files per fax may be attached.'

phaxMachine.pages['send-fax'] = {
	render: function() {
		let dragDrop = new DragDropFileBox();
	}
};

class DragDropFileBox {
	constructor() {
		this.dragDropDivClasses = ['form-group', 'col-lg-8', 'files'];
		this.buttonClasses = ['close-button', 'btn', 'btn-sm', 'btn-danger'];
		this.fileCounter = 1;
		this.allFilesDiv = document.getElementById('all-files');
		this.allFilesDiv.addEventListener('change', this.addRemoveFiles.bind(this));
		this.addedFilesTableEven = document.getElementById('file-table-even');
		this.addedFilesTableOdd = document.getElementById('file-table-odd');
		this.closeButtonIDs = this.updateCloseButtonIDs();
		this.updateAllFilesDiv(this.allFilesDiv.children[0]);//Adds drag/drop color changes on page load
		this.createNewAlert = function() { new MessageAlert('danger', alertMessage).createAlert(); };
	};

	dragOverEventColorChange(event) { event.target.style.backgroundColor = dragOverColor; };
	dragLeaveEventColorChange(event) { event.target.style.backgroundColor = dragLeaveColor; };
	
	addRemoveFiles() {
		if (this.closeButtonIDs.length < 20) {
			this.createNewButtoninAttachedFilesRow();// Add the trashcan icon and the filename under drag/drop box
			this.closeButtonIDs = this.updateCloseButtonIDs();// Update closeButtonIDs in the object with newly added buttons
			this.fileCounter++; // Update fileCounter
			this.createAndAppendNewDiv(); // Add a new drag and drop div based on updated fileCounter
			this.hidePreviousDiv(); // Hide the div file was just drag/dropped into
		} else { // what happens when you exceed the limit
			let divToKill = document.getElementById(`faxFile${this.fileCounter}`);
			divToKill.parentNode.removeChild(divToKill);
			this.createAndAppendNewDiv();
			this.createNewAlert();
		}
		this.updateUploadedFilesMessage();
	};

	updateAllFilesDiv(newDiv) {
		newDiv.addEventListener('dragover', this.dragOverEventColorChange);
		newDiv.addEventListener('dragleave', this.dragLeaveEventColorChange);
	};

	updateUploadedFilesMessage() {
		this.allFilesDiv = document.getElementById('all-files');
		let attachedFilesCounter = document.getElementById('attached-file-counter');
		attachedFilesCounter.innerHTML = `Attached Files: ${this.allFilesDiv.children.length - 1}`;
	};

	updateCloseButtonIDs() {
		let closeButtonIDs = Array.from(document.getElementsByClassName('close-button')).map(button => parseInt(button.id));
		if (closeButtonIDs.length > 0) {
			let foundButtonIDs = closeButtonIDs.filter(buttonID => !this.closeButtonIDs.includes(buttonID));
			if (foundButtonIDs) { this.addTrashCanOnClickEvent(foundButtonIDs); }
		}
		return closeButtonIDs;
	};

	addTrashCanOnClickEvent(foundButtonIDs) {
		foundButtonIDs.forEach(buttonID => {
			let button = document.getElementById(`${buttonID}`);
			button.addEventListener('click', this.removeUploadedFile.bind(this));
		});
	};

	removeUploadedFile(event) {
		let trToKill = document.getElementById(`faxFile${event.target.id}tr`);
		let divToKill = document.getElementById(`faxFile${event.target.id}`);
		divToKill.parentNode.removeChild(divToKill);
		trToKill.parentNode.removeChild(trToKill);
		this.closeButtonIDs = this.updateCloseButtonIDs();
		this.sortUploadedFilesTables();
		this.updateUploadedFilesMessage();
	};

	createAndAppendNewDiv() {
		let newDiv = document.createElement('div');
		newDiv.style.backgroundColor = dragLeaveColor;

		newDiv.id = `faxFile${this.fileCounter}`;
		this.dragDropDivClasses.forEach(className => newDiv.classList.add(className));
		newDiv.innerHTML = `<input id="file${this.fileCounter}" class="drag-drop-input" name="fax[files][file${this.fileCounter}]" type="file">`;
		this.allFilesDiv.appendChild(newDiv);
		this.updateAllFilesDiv(newDiv); //Add dragenter/dragleave events to new div
	};

	hidePreviousDiv() {
		let prevDiv = document.getElementById(`faxFile${this.fileCounter - 1}`);
		prevDiv.style.display = "none";
	};

	createNewButtoninAttachedFilesRow() {
		// Create the row we're inserting into
		let newRow = '';
		let amountFiles = document.getElementsByClassName('fa-trash-o').length;

		if (amountFiles % 2 === 0) {
			newRow = this.addedFilesTableOdd.insertRow(this.addedFilesTableOdd.length);
			newRow.classList.add('table-row-odd');
		} else {
			newRow = this.addedFilesTableEven.insertRow(this.addedFilesTableEven.length);
			newRow.classList.add('table-row-even');
		}
		newRow.id = `faxFile${this.fileCounter}tr`;

		// Create the 1.), 2.), 3.), etc part before button
		let pTag = document.createElement('p');
		pTag.innerHTML = `${amountFiles + 1}.)&nbsp`;
		let pTagTD = newRow.insertCell(0);
		pTagTD.appendChild(pTag);

		// Create the red button in 'fileName.odt' format
		let newTD = newRow.insertCell(1);
		let newButton = document.createElement('button');
		newButton.id = this.fileCounter;
		newButton.innerHTML = `<i class="fa fa-trash-o" aria-hidden="false"></i>&nbsp;&nbsp;${event.target.files[0].name}`;
		this.buttonClasses.forEach(className => newButton.classList.add(className));

		newTD.appendChild(newButton);
	};

	sortUploadedFilesTables() {
		// Wipe out both tables
		let tableFiles = document.getElementsByClassName('close-button');
		let sortedTableFiles = Array.from(tableFiles).sort((divIDa, divIDb) => divIDa.id > divIDb.id);
		let tableRows = Array.from(document.getElementsByClassName('table-row-even')).concat(Array.from(document.getElementsByClassName('table-row-odd')));
		tableRows.forEach(tableRow => tableRow.parentNode.removeChild(tableRow));

		// TODO: Rebuild them with shifted objects
	}
}