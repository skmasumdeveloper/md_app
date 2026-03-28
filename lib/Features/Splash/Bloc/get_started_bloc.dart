import 'package:bloc/bloc.dart';
import 'package:cu_app/Features/Splash/Model/get_started_response_model.dart';
import 'package:cu_app/Features/Splash/Repository/get_started_repository.dart';
import 'package:equatable/equatable.dart';

part 'get_started_event.dart';

part 'get_started_state.dart';

// This Bloc handles the Get Started functionality, managing the state of the application during the initial setup phase.
class GetStartedBloc extends Bloc<GetStartedEvent, GetStartedState> {
  GetStartedBloc() : super(GetStartedStateInitial()) {
    final GetStartedRepository repository = GetStartedRepository();

    on<GetStartedSubmittedEvent>((event, emit) async {
      final RequestGetStarted requestGetStarted =
          RequestGetStarted(isPanel: 'admin');

      try {
        emit(GetStartedStateLoading());
        final mData = await repository.getStarted(requestGetStarted);
        if (mData.status == true) {
          emit(GetStartedStateLoaded(mData));
        } else if (mData.status == false) {
          emit(GetStartedStateFailed(mData.message.toString()));
        }
      } on NetworkError {
        emit(const GetStartedStateFailed("No Internet Connection"));
      }
    });
  }
}
