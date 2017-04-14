// Copyright 2004-present Facebook. All Rights Reserved.

#include <cxxReactABI16_0_0/ABI16_0_0JsArgumentHelpers.h>

#include <folly/dynamic.h>

#include <gtest/gtest.h>
#include <algorithm>

using namespace std;
using namespace folly;
using namespace facebook::xplat;

#define ABI16_0_0EXPECT_JSAE(statement, exstr) do {                              \
    try {                                                               \
      statement;                                                        \
      FAIL() << "Expected JsArgumentException(" << (exstr) << ") not thrown"; \
    } catch (const JsArgumentException& ex) {                           \
      ABI16_0_0EXPECT_EQ(ex.what(), std::string(exstr));                         \
    }                                                                   \
  } while(0) // let any other exception escape, gtest will deal.

TEST(JsArgumentHelpersTest, args) {
  const bool aBool = true;
  const int64_t anInt = 17;
  const double aDouble = 3.14;
  const string aString = "word";
  const dynamic anArray = dynamic::array("a", "b", "c");
  const dynamic anObject = dynamic::object("k1", "v1")("k2", "v2");
  const string aNumericString = to<string>(anInt);

  folly::dynamic args = dynamic::array(aBool, anInt, aDouble, aString, anArray, anObject, aNumericString);

  ABI16_0_0EXPECT_EQ(jsArgAsBool(args, 0), aBool);
  ABI16_0_0EXPECT_EQ(jsArgAsInt(args, 1), anInt);
  ABI16_0_0EXPECT_EQ(jsArgAsDouble(args, 2), aDouble);
  ABI16_0_0EXPECT_EQ(jsArgAsString(args, 3), aString);
  ABI16_0_0EXPECT_EQ(jsArgAsArray(args, 4), anArray);
  ABI16_0_0EXPECT_EQ(jsArgAsObject(args, 5), anObject);

  // const args
  const folly::dynamic& cargs = args;
  const folly::dynamic& a4 = jsArgAsArray(cargs, 4);
  ABI16_0_0EXPECT_EQ(a4, anArray);
  ABI16_0_0EXPECT_EQ(jsArgAsObject(cargs, 5), anObject);

  // helpers returning dynamic should return same object without copying
  ABI16_0_0EXPECT_EQ(&jsArgAsArray(args, 4), &(args[4]));
  ABI16_0_0EXPECT_EQ(&jsArgAsArray(cargs, 4), &(args[4]));

  // dynamics returned for mutable args should be mutable.  The test is that
  // this compiles.
  jsArgAsArray(args, 4)[2] = "d";
  jsArgAsArray(args, 4)[2] = "c";
  // These fail to compile due to constness.
  // jsArgAsArray(cargs, 4)[2] = "d";
  // jsArgAsArray(cargs, 4)[2] = "c";

  // ref-qualified member function tests
  ABI16_0_0EXPECT_EQ(jsArgN(args, 3, &folly::dynamic::getString), aString);
  ABI16_0_0EXPECT_EQ(jsArg(args[3], &folly::dynamic::getString), aString);

  // conversions
  ABI16_0_0EXPECT_EQ(jsArgAsDouble(args, 1), anInt * 1.0);
  ABI16_0_0EXPECT_EQ(jsArgAsString(args, 1), aNumericString);
  ABI16_0_0EXPECT_EQ(jsArgAsInt(args, 6), anInt);

  // Test exception messages.

  // out_of_range
  ABI16_0_0EXPECT_JSAE(jsArgAsBool(args, 7),
              "JavaScript provided 7 arguments for C++ method which references at least "
              "8 arguments: out of range in dynamic array");
  // Conv range_error (invalid value conversion)
  const std::string exhead = "Could not convert argument 3 to required type: ";
  const std::string extail = ": Invalid leading character: \"word\"";
  try {
    jsArgAsInt(args, 3);
    FAIL() << "Expected JsArgumentException(" << exhead << "..." << extail << ") not thrown";
  } catch (const JsArgumentException& ex) {
    const std::string exwhat = ex.what();

    ABI16_0_0EXPECT_GT(exwhat.size(), exhead.size());
    ABI16_0_0EXPECT_GT(exwhat.size(), extail.size());

    ABI16_0_0EXPECT_TRUE(std::equal(exhead.cbegin(), exhead.cend(), exwhat.cbegin()))
      << "JsArgumentException('" << exwhat << "') does not begin with '" << exhead << "'";
    ABI16_0_0EXPECT_TRUE(std::equal(extail.crbegin(), extail.crend(), exwhat.crbegin()))
      << "JsArgumentException('" << exwhat << "') does not end with '" << extail << "'";
  }
  // inconvertible types
  ABI16_0_0EXPECT_JSAE(jsArgAsArray(args, 2),
              "Argument 3 of type double is not required type Array");
  ABI16_0_0EXPECT_JSAE(jsArgAsInt(args, 4),
              "Error converting javascript arg 4 to C++: "
              "TypeError: expected dynamic type `int/double/bool/string', but had type `array'");
  // type predicate failure
  ABI16_0_0EXPECT_JSAE(jsArgAsObject(args, 4),
              "Argument 5 of type array is not required type Object");
}