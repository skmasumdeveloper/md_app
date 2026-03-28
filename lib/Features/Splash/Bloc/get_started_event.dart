part of 'get_started_bloc.dart';

// This file defines the events for the Get Started functionality in the application.
abstract class GetStartedEvent extends Equatable {
  const GetStartedEvent();

  @override
  List<Object> get props => [];
}

class GetStartedSubmittedEvent extends GetStartedEvent {}
