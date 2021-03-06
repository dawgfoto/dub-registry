/**
	Copyright: © 2013 rejectedsoftware e.K.
	License: Subject to the terms of the GNU GPLv3 license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module dubregistry.repositories.repository;

import vibe.vibe;

import dubregistry.cache;
import std.digest.sha;


Repository getRepository(Json repinfo)
{
	auto ident = repinfo.toString();
	if( auto pr = ident in s_repositories )
		return *pr;

	logDebug("Returning new repository: %s", ident);
	auto pf = repinfo.kind.get!string in s_repositoryFactories;
	enforce(pf, "Unknown repository type: "~repinfo.kind.get!string);
	auto rep = (*pf)(repinfo);
	s_repositories[ident] = rep;
	return rep;
}

void addRepositoryFactory(string kind, RepositoryFactory factory)
{
	assert(kind !in s_repositoryFactories);
	s_repositoryFactories[kind] = factory;
}

package Json readJson(string url, bool sanitize = false, bool cache_priority = false)
{
	Json ret;
	logDiagnostic("Getting JSON response from %s", url);
	try downloadCached(url, (scope input){
		auto text = input.readAllUTF8(sanitize);
		ret = parseJsonString(text);
	}, cache_priority);
	catch (Exception e) {
		throw new Exception(format("Failed to read JSON from %s: %s", url, e.msg), __FILE__, __LINE__, e);
	}
	return ret;
}


alias RepositoryFactory = Repository delegate(Json);

struct PackageVersionInfo {
	SysTime date;
	string version_;
	Json info;
}

interface Repository {
	string[] getVersions();
	string[] getBranches();
	PackageVersionInfo getVersionInfo(string ver);
	string getDownloadUrl(string ver);
}

struct CommitInfo {
	string sha;
	BsonDate date;

	this(string sha, string date)
	{
		this.sha = sha;
		this.date = BsonDate(SysTime.fromISOExtString(date));
	}
}

private {
	Repository[string] s_repositories;
	RepositoryFactory[string] s_repositoryFactories;
}
