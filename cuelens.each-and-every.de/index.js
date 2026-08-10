(function() {
	const PROLIFIC_ID_PATTERN = /^[A-Za-z0-9]{24}$/;
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
	const personalFields = [nameInput, ibanInput, bicInput].filter(Boolean);

	if (!form || !emailInput) {
		return;
	}

	function isSyntacticallyValidProlificId(value) {
		return PROLIFIC_ID_PATTERN.test(value.trim());
	}

	function isSyntacticallyValidEmail(value) {
		const candidate = value.trim();
		if (candidate === '') {
			return false;
		}
		const probe = document.createElement('input');
		probe.type = 'email';
		probe.value = candidate;
		return probe.checkValidity();
	}

	function classifyParticipantIdentifier(value) {
		if (isSyntacticallyValidProlificId(value)) {
			return 'prolific';
		}
		if (isSyntacticallyValidEmail(value)) {
			return 'direct';
		}
		return 'invalid';
	}

	function applyRegistrationMode(mode) {
		form.dataset.registrationMode = mode;
		const prolific = mode === 'prolific';
		personalFields.forEach((input) => {
			if (prolific) {
				input.value = '';
				input.setCustomValidity('');
				input.required = false;
				input.disabled = true;
			} else {
				input.disabled = false;
				input.required = true;
			}
		});
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
		if (input === emailInput) {
			const value = input.value.trim();
			if (value === '') {
				input.setCustomValidity(input.dataset.validationRequired || '');
			} else if (classifyParticipantIdentifier(value) === 'invalid') {
				input.setCustomValidity(input.dataset.validationInvalid || '');
			}
		}
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
			if (input === emailInput) {
				applyRegistrationMode(classifyParticipantIdentifier(input.value));
			}
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

	applyRegistrationMode(classifyParticipantIdentifier(emailInput.value));
	window.CueLensRegistration = {
		isSyntacticallyValidProlificId,
		classifyParticipantIdentifier,
		applyRegistrationMode,
	};
})();
