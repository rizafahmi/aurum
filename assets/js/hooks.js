// Custom hooks for Aurum application

export const hooks = {
  ToggleForm: {
    mounted() {
      this.el.addEventListener("click", () => {
        const formContainer = document.getElementById("add-holding-form-container");
        if (formContainer) {
          formContainer.classList.toggle("hidden");
        }
      });
    }
  }
};
