part of 'user_report_bloc.dart';

// This file defines the events for user reporting in the application.
abstract class UserReportState extends Equatable {
  const UserReportState();

  @override
  List<Object> get props => [];
}

class UserReportStateInitial extends UserReportState {}

class UserReportStateLoading extends UserReportState {}

class UserReportStateLoaded extends UserReportState {
  final UserReportResponseModel userReportResponseModel;

  const UserReportStateLoaded(this.userReportResponseModel);

  @override
  List<Object> get props => [userReportResponseModel];
}

class UserReportStateFailed extends UserReportState {
  final String msg;

  const UserReportStateFailed(this.msg);

  @override
  List<Object> get props => [msg];
}
