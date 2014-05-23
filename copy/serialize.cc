// Copyright 2014, Georg Sauthoff <mail@georg.so>

/* {{{ GPLv3

    This file is part of imapdl.

    imapdl is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    imapdl is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with imapdl.  If not, see <http://www.gnu.org/licenses/>.

}}} */
#include "serialize.h"
#include "client.h"

#include <boost/archive/text_iarchive.hpp>
#include <boost/archive/text_oarchive.hpp>
#include <boost/serialization/vector.hpp>
#include <boost/serialization/utility.hpp>
#include <boost/serialization/version.hpp>

#include <fstream>
using namespace std;

#include "sequence_set.h"

namespace boost {
  namespace serialization {

    template<class Archive>
      void serialize(Archive & a, IMAP::Copy::Journal &d, const unsigned int version)
      {
        a & d.mailbox_;
        a & d.uidvalidity_;
        a & d.uids_;
      }

  }
}

namespace IMAP {
  namespace Copy {

    Journal::Journal(const string &mailbox, uint32_t uidvalidity, const Sequence_Set &set)
      :
        mailbox_(mailbox),
        uidvalidity_(uidvalidity)
    {
      set.copy(uids_);
    }
    Journal::Journal()
    {
    }

    void Journal::read(const std::string &filename)
    {
      ifstream f;
      f.exceptions(ofstream::failbit | ofstream::badbit );
      f.open(filename, ofstream::in | ofstream::binary);
      boost::archive::text_iarchive a(f);
      a >> *this;
    }
    void Journal::write(const std::string &filename)
    {
      ofstream f;
      f.exceptions(ofstream::failbit | ofstream::badbit );
      f.open(filename, ofstream::out | ofstream::binary);
      boost::archive::text_oarchive a(f);
      a << *this;
    }


  }
}
