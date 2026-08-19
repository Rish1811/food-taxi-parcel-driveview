class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool isSuccess;

  const ApiResponse.success(this.data, [this.message]) : isSuccess = true;
  const ApiResponse.error(this.message, [this.data]) : isSuccess = false;
}
