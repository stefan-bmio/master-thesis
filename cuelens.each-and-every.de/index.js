(function() {
	const emailInput = document.getElementById('email');
	const nameInput = document.getElementById('name');
	const ibanInput = document.getElementById('iban');
	const bicInput = document.getElementById('bic');
	const ageInput = document.getElementById('age');
	const cigarettesInput = document.getElementById('cigarettes');
	const studyinfoInput = document.getElementById('studyinfo');
	const dataprotInput = document.getElementById('dataprot');
	const form = document.querySelector('form');
	const validationMessage = document.getElementById('form-validation-message');

	if (!form) {
		return;
	}

	const managedFields = [
		emailInput,
		nameInput,
		ibanInput,
		bicInput,
		ageInput,
		cigarettesInput,
		studyinfoInput,
		dataprotInput,
	].filter(Boolean);

	function getValidationMessage(input) {
		const validity = input.validity;

		if (validity.valueMissing) {
			return input.dataset.validationRequired || '';
		}

		if (validity.rangeUnderflow || validity.rangeOverflow) {
			return input.dataset.validationRange || '';
		}

		if (validity.stepMismatch) {
			return input.dataset.validationStep || '';
		}

		if (!validity.valid) {
			return input.validationMessage || '';
		}

		return '';
	}

	function validateField(input) {
		input.setCustomValidity('');
		const message = getValidationMessage(input);
		input.setCustomValidity(message);
		return message;
	}

	function setVisibleMessage(message) {
		if (!validationMessage) {
			return;
		}

		validationMessage.textContent = message;
		validationMessage.hidden = message === '';
	}

	function validateManagedFields() {
		let firstInvalid = null;

		managedFields.forEach((input) => {
			const message = validateField(input);

			if (message && firstInvalid === null) {
				firstInvalid = { input, message };
			}
		});

		return firstInvalid;
	}

	function updateVisibleMessageIfShown() {
		if (!validationMessage || validationMessage.hidden) {
			return;
		}

		const firstInvalid = validateManagedFields();
		setVisibleMessage(firstInvalid ? firstInvalid.message : '');
	}

	managedFields.forEach((input) => {
		const eventName = input.type === 'checkbox' ? 'change' : 'input';

		validateField(input);

		input.addEventListener(eventName, () => {
			validateField(input);
			updateVisibleMessageIfShown();
		});

		input.addEventListener('invalid', (event) => {
			event.preventDefault();
			const firstInvalid = validateManagedFields();

			if (firstInvalid) {
				setVisibleMessage(firstInvalid.message);
				firstInvalid.input.focus();
			}
		});
	});

	form.addEventListener('submit', () => {
		const firstInvalid = validateManagedFields();
		setVisibleMessage(firstInvalid ? firstInvalid.message : '');
	});
})();
