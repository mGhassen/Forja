/// Android build flavor on the `formFactor` dimension (`tv` / `mobile`).
///
/// Native reports it from `BuildConfig.FORM_FACTOR`; `--flavor` also sets
/// [appFlavor] at compile time, used when the channel does not answer.
enum AndroidFormFactor {
  tv,
  mobile;

  /// Unknown or missing → [tv], the behavior of builds before the split.
  static AndroidFormFactor parse(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'mobile' => AndroidFormFactor.mobile,
        _ => AndroidFormFactor.tv,
      };
}
