extension StringExtension on String {
  String take(int n) => length >= n ? substring(0, n) : this;
}
