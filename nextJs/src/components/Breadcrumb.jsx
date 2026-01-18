"use client";
import React from "react";
import { Icon } from "@iconify/react";
import Link from "next/link";
const Breadcrumb = ({ title }) => {
  return (
    <>
      <div className='d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24 cvant-breadcrumb-row'>
        <h6 className='fw-semibold mb-0 cvant-breadcrumb-title'>Dashboard</h6>
        <ul className='d-flex align-items-center gap-2 cvant-breadcrumb-list'>
        <li className='fw-medium'>
          <Link
            href='/'
            className='d-flex align-items-center gap-1 hover-text-primary'
          >
            <Icon
              icon='solar:home-smile-angle-outline'
              className='icon text-lg'
            />
            Dashboard
          </Link>
        </li>
        <li> - </li>
        <li className='fw-medium'>{title}</li>
        </ul>
      </div>

      <style jsx global>{`
        @media (max-width: 576px) {
          .cvant-breadcrumb-row {
            flex-wrap: nowrap !important;
            gap: 8px !important;
          }

          .cvant-breadcrumb-title {
            font-size: 14px !important;
            line-height: 1.2 !important;
            white-space: nowrap !important;
          }

          .cvant-breadcrumb-list,
          .cvant-breadcrumb-list * {
            font-size: 13px !important;
            line-height: 1.2 !important;
            white-space: nowrap !important;
          }
        }
      `}</style>
    </>
  );
};

export default Breadcrumb;
