#
# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PROTOC = protoc
GRPC_CPP_PLUGIN = grpc_cpp_plugin
GRPC_CPP_PLUGIN_PATH ?= `which $(GRPC_CPP_PLUGIN)`
PROTO_PATH = ./protos
PROTO_SRCS := $(wildcard $(PROTO_PATH)/*.proto)
PROTO_OBJS := $(patsubst $(PROTO_PATH)/%.proto,$(PROTO_PATH)/%.pb.o,$(PROTO_SRCS))
PROTO_C_SRCS := $(patsubst $(PROTO_PATH)/%.proto,$(PROTO_PATH)/%.pb.cc,$(PROTO_SRCS))
PROTO_GRPC_OBJS := $(patsubst $(PROTO_PATH)/%.proto,$(PROTO_PATH)/%.grpc.pb.o,$(PROTO_SRCS))
PROTO_GRPC_C_SRCS := $(patsubst $(PROTO_PATH)/%.proto,$(PROTO_PATH)/%.grpc.pb.cc,$(PROTO_SRCS))

PINPT_PATH = ./pinpoint
PINPT_SRCS := $(wildcard $(PINPT_PATH)/*.cc)
PINPT_OBJS := $(patsubst $(PINPT_PATH)/%.cc,$(PINPT_PATH)/%.o,$(PINPT_SRCS))

vpath %.proto $(PROTO_PATH)

HOST_SYSTEM = $(shell uname | cut -f 1 -d_)
SYSTEM ?= $(HOST_SYSTEM)
CXX = g++
CPPFLAGS += `pkg-config --cflags protobuf grpc`
CXXFLAGS += -std=c++11 -I$(PROTO_PATH) -I$(PINPT_PATH)
ifeq ($(SYSTEM),Darwin)
LDFLAGS += -L/usr/local/lib `pkg-config --libs protobuf grpc++ grpc`\
           -pthread\
           -lgrpc++_reflection\
           -ldl
else
LDFLAGS += -L/usr/local/lib `pkg-config --libs protobuf grpc++ grpc`\
           -pthread\
           -Wl,--no-as-needed -lgrpc++_reflection -Wl,--as-needed\
           -ldl
endif

all: system-check gen_pb gen_grpc greeter_client greeter_server greeter_async_client greeter_async_client2 greeter_async_server

gen_pb: $(PROTO_SRCS)
	$(PROTOC) -I $(PROTO_PATH) --cpp_out=$(PROTO_PATH) $^

gen_grpc: $(PROTO_SRCS)
	$(PROTOC) -I $(PROTO_PATH) --grpc_out=$(PROTO_PATH) --plugin=protoc-gen-grpc=$(GRPC_CPP_PLUGIN_PATH) $^

$(PINPT_OBJS): $(PINPT_PATH)/%.o: $(PINPT_PATH)/%.cc
	@echo $(PINPT_OBJS)
	$(CXX) -g $(CXXFLAGS) -c -o $@ $<

$(PROTO_OBJS):
	$(foreach src, $(PROTO_C_SRCS), \
	$(CXX) -g $(src) $(LDFLAGS) -c -o $(patsubst $(PROTO_PATH)/%.pb.cc,$(PROTO_PATH)/%.pb.o,$(src));)

$(PROTO_GRPC_OBJS):
	$(foreach src, $(PROTO_GRPC_C_SRCS), \
	$(CXX) -g $(src) $(LDFLAGS) -c -o $(patsubst $(PROTO_PATH)/%.grpc.pb.cc,$(PROTO_PATH)/%.grpc.pb.o,$(src));)

greeter_client: $(PINPT_OBJS) $(PROTO_OBJS) $(PROTO_GRPC_OBJS) greeter_client.o
	$(CXX) $^ $(CXXFLAGS) $(LDFLAGS) -o $@

greeter_server: $(PINPT_OBJS) $(PROTO_OBJS) $(PROTO_GRPC_OBJS) greeter_server.o
	$(CXX) $^ $(CXXFLAGS) $(LDFLAGS) -o $@

greeter_async_client: $(PINPT_OBJS) $(PROTO_OBJS) $(PROTO_GRPC_OBJS) greeter_async_client.o
	$(CXX) $^ $(CXXFLAGS) $(LDFLAGS) -o $@

greeter_async_client2: $(PINPT_OBJS) $(PROTO_OBJS) $(PROTO_GRPC_OBJS) greeter_async_client2.o
	$(CXX) $^ $(CXXFLAGS) $(LDFLAGS) -o $@

greeter_async_server: $(PINPT_OBJS) $(PROTO_OBJS) $(PROTO_GRPC_OBJS) greeter_async_server.o
	$(CXX) $^ $(CXXFLAGS) $(LDFLAGS) -o $@

clean:
	rm -f $(PROTO_PATH)/*.pb.cc $(PROTO_PATH)/*.pb.h greeter_client greeter_server greeter_async_client greeter_async_client2 greeter_async_server
	rm -f *.o $(PINPT_PATH)/*.o $(PROTO_PATH)/*.o


# The following is to test your system and ensure a smoother experience.
# They are by no means necessary to actually compile a grpc-enabled software.

PROTOC_CMD = which $(PROTOC)
PROTOC_CHECK_CMD = $(PROTOC) --version | grep -q libprotoc.3
PLUGIN_CHECK_CMD = which $(GRPC_CPP_PLUGIN)
HAS_PROTOC = $(shell $(PROTOC_CMD) > /dev/null && echo true || echo false)
ifeq ($(HAS_PROTOC),true)
HAS_VALID_PROTOC = $(shell $(PROTOC_CHECK_CMD) 2> /dev/null && echo true || echo false)
endif
HAS_PLUGIN = $(shell $(PLUGIN_CHECK_CMD) > /dev/null && echo true || echo false)

SYSTEM_OK = false
ifeq ($(HAS_VALID_PROTOC),true)
ifeq ($(HAS_PLUGIN),true)
SYSTEM_OK = true
endif
endif

system-check:
ifneq ($(HAS_VALID_PROTOC),true)
	@echo " DEPENDENCY ERROR"
	@echo
	@echo "You don't have protoc 3.0.0 installed in your path."
	@echo "Please install Google protocol buffers 3.0.0 and its compiler."
	@echo "You can find it here:"
	@echo
	@echo "   https://github.com/google/protobuf/releases/tag/v3.0.0"
	@echo
	@echo "Here is what I get when trying to evaluate your version of protoc:"
	@echo
	-$(PROTOC) --version
	@echo
	@echo
endif
ifneq ($(HAS_PLUGIN),true)
	@echo " DEPENDENCY ERROR"
	@echo
	@echo "You don't have the grpc c++ protobuf plugin installed in your path."
	@echo "Please install grpc. You can find it here:"
	@echo
	@echo "   https://github.com/grpc/grpc"
	@echo
	@echo "Here is what I get when trying to detect if you have the plugin:"
	@echo
	-which $(GRPC_CPP_PLUGIN)
	@echo
	@echo
endif
ifneq ($(SYSTEM_OK),true)
	@false
endif
