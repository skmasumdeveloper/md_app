part of 'get_started_bloc.dart';

// This file defines the states for the Get Started functionality in the application.
abstract class GetStartedState extends Equatable {
  const GetStartedState();

  @override
  List<Object> get props => [];
}

class GetStartedStateInitial extends GetStartedState {}

class GetStartedStateLoading extends GetStartedState {}

class GetStartedStateLoaded extends GetStartedState {
  final ResponseGetStarted responseGetStarted;

  const GetStartedStateLoaded(this.responseGetStarted);

  @override
  List<Object> get props => [responseGetStarted];
}

class GetStartedStateFailed extends GetStartedState {
  final String msg;

  const GetStartedStateFailed(this.msg);

  @override
  List<Object> get props => [msg];
}
