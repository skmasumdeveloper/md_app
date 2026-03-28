import 'package:bloc/bloc.dart';
import 'package:cu_app/Features/ReportScreen/Model/user_report_model.dart';
import 'package:cu_app/Features/ReportScreen/Repository/user_report_repository.dart';
import 'package:equatable/equatable.dart';

part 'user_report_event.dart';

part 'user_report_state.dart';

// This Bloc handles user report events and manages the state of user reports in the application.
class UserReportBloc extends Bloc<UserReportEvent, UserReportState> {
  UserReportBloc() : super(UserReportStateInitial()) {
    final UserReportRepository repository = UserReportRepository();

    on<UserReportSubmittedEvent>((event, emit) async {
      final Map<String, dynamic> request = {
        "group_id": event.groupId,
        "group_name": event.groupName,
        "report_by_id": event.reportById,
        "report_by_name": event.reportByName,
        "report_to_id": event.reportToId,
        "report_to_name": event.reportToName,
        "report_reason": event.reportReason,
        "message": event.message,
        "type": event.type
      };

      try {
        emit(UserReportStateLoading());
        final mData = await repository.userReport(request);
        if (mData.status == true) {
          emit(UserReportStateLoaded(mData));
        } else if (mData.status == false) {
          emit(UserReportStateFailed(mData.message.toString()));
        }
      } on NetworkError {
        emit(const UserReportStateFailed("No Internet Connection"));
      }
    });
  }
}
