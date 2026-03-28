part of 'user_report_bloc.dart';

// This file defines the events for user reporting in the application.
abstract class UserReportEvent extends Equatable {
  const UserReportEvent();

  @override
  List<Object> get props => [];
}

class UserReportSubmittedEvent extends UserReportEvent {
  final String groupId;
  final String groupName;
  final String reportById;
  final String reportByName;
  final String reportToId;
  final String reportToName;
  final String reportReason;
  final String message;
  final String type;

  const UserReportSubmittedEvent(
      this.groupId,
      this.groupName,
      this.reportById,
      this.reportByName,
      this.reportToId,
      this.reportToName,
      this.reportReason,
      this.message,
      this.type);

  @override
  List<Object> get props => [
        groupId,
        groupName,
        reportById,
        reportByName,
        reportToId,
        reportToName,
        reportReason,
        message,
        type
      ];
}
