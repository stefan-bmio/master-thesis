(function() {
	const ageInput = document.getElementById('age');
	const cigarettesInput = document.getElementById('cigarettes');

	ageInput.addEventListener('input', () => {
		ageInput.setCustomValidity('');

		if (ageInput.validity.valueMissing) {
			ageInput.setCustomValidity('Bitte geben Sie Ihr Alter ein.');
		} else if (ageInput.validity.rangeUnderflow || ageInput.validity.rangeOverflow) {
			ageInput.setCustomValidity('Eine Teilnahme ist nur im Alter von 30 bis 65 Jahren möglich.');
		} else if (ageInput.validity.stepMismatch) {
			ageInput.setCustomValidity('Bitte geben Sie eine ganze Zahl ein.');
		}
	});

	cigarettesInput.addEventListener('input', () => {
		cigarettesInput.setCustomValidity('');

		if (cigarettesInput.validity.valueMissing) {
			cigarettesInput.setCustomValidity('Bitte geben Sie die Anzahl der Zigaretten pro Tag ein.');
		} else if (cigarettesInput.validity.rangeUnderflow) {
			cigarettesInput.setCustomValidity('Eine Teilnahme ist nur bei mindestens 10 Zigaretten pro Tag möglich.');
		} else if (cigarettesInput.validity.stepMismatch) {
			cigarettesInput.setCustomValidity('Bitte geben Sie eine ganze Zahl ein.');
		}
	});

	const form = document.querySelector('form');

	form.addEventListener('submit', () => {
		ageInput.dispatchEvent(new Event('input'));
		cigarettesInput.dispatchEvent(new Event('input'));
	});
})();