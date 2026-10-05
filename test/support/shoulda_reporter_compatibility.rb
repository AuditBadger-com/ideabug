# shoulda-context 2.0.0 overrides Rails' rerun formatter using the old instance
# accessor. Rails 8 exposes executable on the reporter class instead.
module ShouldaReporterCompatibility
  private

  def executable
    self.class.executable
  end
end

Rails::TestUnitReporter.prepend(ShouldaReporterCompatibility)
