#include <iostream>
#include <memory>
#include <string>
#include <chrono>
#include <thread>
#include <grpcpp/grpcpp.h>
#include "Span.grpc.pb.h"
#include "Service.grpc.pb.h"
#include "Cmd.grpc.pb.h"
#include "Stat.grpc.pb.h"
#include "ThreadDump.grpc.pb.h"
#include "pinpoint.h"
#include "pinpoint_internal.h"

using namespace Pinpt;
using namespace std;

Span::Span(Agent *agent)
{
	string agentid = agent->get_agentid();
	string agent_starttime = agent->get_starttime();

	set_context(agentid);
	connect();

	span.set_starttime(get_time());
	span.set_version(SPAN_GRPC_VERSION);
	span.set_servicetype(1000);
	span.set_applicationservicetype(1000);
	span.set_spanid(CLIENT_SPANID);
	span.set_parentspanid(ROOT_PARENT_ID);


	// set the parent info
	parentInfo.set_parentapplicationname(APPNAME);
	parentInfo.set_parentapplicationtype(1000);

	transactionId.set_agentid(agentid);
	transactionId.set_agentstarttime(stol(agent_starttime));
	transactionId.set_sequence(UNIQ_SEQ);
}

void Span::set_context(string agentid)
{
	context.AddMetadata("agentid", agentid);
	context.AddMetadata("applicationname", agentid);
	context.AddMetadata("starttime", get_stime());
}

void Span::set_parentAppname(string pAppname)
{
	parentInfo.set_parentapplicationname(pAppname);
}

void Span::prepare_span(long int clientid, long int parentid, long int seq)
{
	v1::PSpanEvent *spanEvent = span.add_spanevent();
	spanEvent->set_sequence(seq);
	spanEvent->set_depth(1);

	span.set_elapsed(span.starttime() - get_time());
	span.set_spanid(clientid);
	span.set_parentspanid(parentid);
	transactionId.set_sequence(seq);

	nextEvent.mutable_messageevent()->CopyFrom(msgEvent);
	spanEvent->mutable_nextevent()->CopyFrom(nextEvent);
	acceptEvent.mutable_parentinfo()->CopyFrom(parentInfo);
	span.mutable_acceptevent()->CopyFrom(acceptEvent);
	span.mutable_transactionid()->CopyFrom(transactionId);

	// set span to spanmessage
	msg.mutable_span()->CopyFrom(span);
}

void Span::send_span(long int clientid, long int parentid, long int seq)
{
	prepare_span(clientid, parentid, seq);

	writer->Write(msg);
	writer->WritesDone();
	Status status = writer->Finish();

	if (status.ok()) {
		std::cout << "[SPAN] : " << "Finished \n";
	} else {
		status.error_message();
		status.error_code();
		cout << "[SPAN] : FAIL REASON : " << status.error_message() << " " << status.error_code() << endl;
	}
}


void Span::connect()
{
	channel = grpc::CreateChannel(HOST_SPAN, grpc::InsecureChannelCredentials());
	stub = v1::Span::NewStub(channel);
	writer = (stub->SendSpan(&context, &empty));
}
